#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 186: FIND CORRECT NDK LIBUNWIND + LINK"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"
RUNNER="$(command -v glibc-runner)"
BOX64="$GLIBC/bin/box64"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
BIN="$X86/bin"
SYSROOT="$X86/sysroot"

CLANG="$BIN/clang"
LLD="$BIN/ld.lld"

RESOURCE="$X86/lib/clang/19"
RESLIB="$RESOURCE/lib/linux"
LIBDIR="$SYSROOT/usr/lib/aarch64-linux-android/21"

TESTDIR="$HOME/pocket_pcr_studio/phase186_test"
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"

echo
echo "--- 1. BASIC TOOLS ---"
echo "RUNNER=$RUNNER"
echo "BOX64=$BOX64"
echo "CLANG=$CLANG"
echo "LLD=$LLD"
echo "NDK=$NDK"
echo "SYSROOT=$SYSROOT"
echo "RESOURCE=$RESOURCE"
echo "RESLIB=$RESLIB"
echo "LIBDIR=$LIBDIR"

echo
echo "--- 2. BOX64 ---"
"$RUNNER" "$BOX64" --version 2>&1
BOX64_RC=$?
echo "BOX64_RC=$BOX64_RC"

echo
echo "--- 3. CLANG ---"
"$RUNNER" "$BOX64" "$CLANG" --version 2>&1 | head -5
CLANG_RC=${PIPESTATUS[0]}
echo "CLANG_RC=$CLANG_RC"

echo
echo "--- 4. CREATE TEST SOURCE ---"

cat > "$TESTDIR/test.c" <<'SRC'
int main(void) {
    return 0;
}
SRC

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -c "$TESTDIR/test.c" \
    -o "$TESTDIR/test.o" \
    2>&1

COMPILE_RC=$?

echo "COMPILE_RC=$COMPILE_RC"

if [ -f "$TESTDIR/test.o" ]; then
    echo "OBJECT=YES"
    file "$TESTDIR/test.o"
else
    echo "OBJECT=NO"
fi

echo
echo "--- 5. SEARCH LIBUNWIND ---"

find "$NDK" \
    -type f \
    \( -name 'libunwind.a' -o -name 'libunwind.so' -o -name 'libunwind.so.*' \) \
    2>/dev/null | sort | tee "$TESTDIR/libunwind_paths.txt"

UNWIND_COUNT=$(wc -l < "$TESTDIR/libunwind_paths.txt")
echo "UNWIND_COUNT=$UNWIND_COUNT"

echo
echo "--- 6. VERIFY LIBUNWIND FILES ---"

while IFS= read -r F; do
    [ -z "$F" ] && continue
    echo
    echo "FILE=$F"
    ls -lh "$F"
    file "$F"
done < "$TESTDIR/libunwind_paths.txt"

echo
echo "--- 7. SEARCH CLANG BUILTINS ---"

BUILTINS=$(find "$X86/lib/clang/19" \
    -type f \
    -name 'libclang_rt.builtins-aarch64-android.a' \
    2>/dev/null | head -1)

echo "BUILTINS=$BUILTINS"

if [ -n "$BUILTINS" ]; then
    BUILTINS_EXISTS=YES
else
    BUILTINS_EXISTS=NO
fi

echo "BUILTINS_EXISTS=$BUILTINS_EXISTS"

echo
echo "--- 8. SELECT LIBUNWIND ---"

UNWIND=""

while IFS= read -r F; do
    [ -z "$F" ] && continue

    case "$F" in
        */libunwind.a)
            UNWIND="$F"
            break
            ;;
    esac
done < "$TESTDIR/libunwind_paths.txt"

if [ -n "$UNWIND" ]; then
    echo "SELECTED_UNWIND=$UNWIND"
    file "$UNWIND"
else
    echo "SELECTED_UNWIND=NONE"
fi

echo
echo "--- 9. REQUIRED FILES ---"

for F in \
    "$BUILTINS" \
    "$LIBDIR/crtbegin_dynamic.o" \
    "$LIBDIR/crtend_android.o" \
    "$LIBDIR/libc.so" \
    "$LIBDIR/libdl.so"
do
    if [ -n "$F" ] && [ -f "$F" ]; then
        echo "FOUND=$F"
    else
        echo "MISSING=$F"
    fi
done

echo
echo "--- 10. DIRECT LLD LINK ---"

if [ -f "$TESTDIR/test.o" ] && \
   [ -n "$BUILTINS" ] && \
   [ -n "$UNWIND" ] && \
   [ -f "$LIBDIR/crtbegin_dynamic.o" ] && \
   [ -f "$LIBDIR/crtend_android.o" ]; then

    "$RUNNER" "$BOX64" "$LLD" \
        -m aarch64linux \
        -pie \
        -dynamic-linker /system/bin/linker64 \
        -z now \
        -z relro \
        -z max-page-size=16384 \
        -o "$TESTDIR/direct_link" \
        "$LIBDIR/crtbegin_dynamic.o" \
        "$TESTDIR/test.o" \
        "$BUILTINS" \
        "$UNWIND" \
        "$LIBDIR/libdl.so" \
        "$LIBDIR/libc.so" \
        "$LIBDIR/crtend_android.o" \
        2>&1

    DIRECT_RC=$?
else
    echo "SKIPPED: required input missing"
    DIRECT_RC=99
fi

echo "DIRECT_RC=$DIRECT_RC"

if [ -f "$TESTDIR/direct_link" ]; then
    echo "DIRECT_LINK_CREATED=YES"
    file "$TESTDIR/direct_link"
else
    echo "DIRECT_LINK_CREATED=NO"
fi

echo
echo "--- 11. CLANG DRIVER LINK ---"

if [ -f "$TESTDIR/test.o" ]; then

    "$RUNNER" "$BOX64" "$CLANG" \
        --target=aarch64-linux-android21 \
        --sysroot="$SYSROOT" \
        -fuse-ld=lld \
        -rtlib=compiler-rt \
        -unwindlib=libunwind \
        -Wl,-z,max-page-size=16384 \
        "$TESTDIR/test.o" \
        -o "$TESTDIR/clang_link" \
        2>&1

    CLANG_LINK_RC=$?
else
    CLANG_LINK_RC=99
fi

echo "CLANG_LINK_RC=$CLANG_LINK_RC"

if [ -f "$TESTDIR/clang_link" ]; then
    echo "CLANG_LINK_CREATED=YES"
    file "$TESTDIR/clang_link"
else
    echo "CLANG_LINK_CREATED=NO"
fi

echo
echo "--- 12. CLANG DRIVER VERBOSE LINK ---"

if [ -f "$TESTDIR/test.o" ]; then

    "$RUNNER" "$BOX64" "$CLANG" \
        --target=aarch64-linux-android21 \
        --sysroot="$SYSROOT" \
        -fuse-ld=lld \
        -rtlib=compiler-rt \
        -unwindlib=libunwind \
        -Wl,-z,max-page-size=16384 \
        -v \
        "$TESTDIR/test.o" \
        -o "$TESTDIR/verbose_link" \
        2>&1 | tee "$TESTDIR/verbose.log"

    TRACE_RC=${PIPESTATUS[0]}
else
    TRACE_RC=99
fi

echo "TRACE_RC=$TRACE_RC"

echo
echo "--- 13. FINAL INVENTORY ---"
find "$TESTDIR" -maxdepth 1 -type f \
    -printf '%f\n' 2>/dev/null | sort

echo
echo "--- 14. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "BOX64_RC=$BOX64_RC"
echo "CLANG_RC=$CLANG_RC"
echo "COMPILE_RC=$COMPILE_RC"
echo "UNWIND_COUNT=$UNWIND_COUNT"
echo "BUILTINS_EXISTS=$BUILTINS_EXISTS"
echo "DIRECT_RC=$DIRECT_RC"
echo "CLANG_LINK_RC=$CLANG_LINK_RC"
echo "TRACE_RC=$TRACE_RC"

if [ "$DIRECT_RC" = "0" ]; then
    echo "DIRECT_LINK_STATUS=SUCCESS"
else
    echo "DIRECT_LINK_STATUS=FAILED"
fi

if [ "$CLANG_LINK_RC" = "0" ]; then
    echo "CLANG_DRIVER_STATUS=SUCCESS"
else
    echo "CLANG_DRIVER_STATUS=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 186 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TESTDIR"
echo "RESULT_FILE=$HOME/pocket_pcr_studio/phase186_result.txt"
echo "=================================================="
