#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 185: CORRECT BUILTINS + FINAL ANDROID LINK"
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

BUILTINS="$RESLIB/libclang_rt.builtins-aarch64-android.a"
UNWIND="$RESLIB/libunwind.a"
CRTBEGIN="$LIBDIR/crtbegin_dynamic.o"
CRTEND="$LIBDIR/crtend_android.o"
LIBC="$LIBDIR/libc.so"
LIBDL="$LIBDIR/libdl.so"

TESTDIR="$HOME/pocket_pcr_studio/phase185_test"
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"

echo
echo "--- 1. PATHS ---"
echo "NDK=$NDK"
echo "CLANG=$CLANG"
echo "LLD=$LLD"
echo "RESOURCE=$RESOURCE"
echo "RESLIB=$RESLIB"
echo "SYSROOT=$SYSROOT"
echo "LIBDIR=$LIBDIR"
echo "BUILTINS=$BUILTINS"
echo "UNWIND=$UNWIND"
echo "CRTBEGIN=$CRTBEGIN"
echo "CRTEND=$CRTEND"
echo "LIBC=$LIBC"
echo "LIBDL=$LIBDL"

echo
echo "--- 2. REQUIRED FILES ---"

for F in \
    "$BUILTINS" \
    "$UNWIND" \
    "$CRTBEGIN" \
    "$CRTEND" \
    "$LIBC" \
    "$LIBDL"
do
    if [ -f "$F" ]; then
        echo "FOUND: $F"
        file "$F"
    else
        echo "MISSING: $F"
    fi
done

echo
echo "--- 3. BOX64 ---"
"$RUNNER" "$BOX64" --version 2>&1
BOX64_RC=$?
echo "BOX64_RC=$BOX64_RC"

echo
echo "--- 4. CLANG ---"
"$RUNNER" "$BOX64" "$CLANG" --version 2>&1
CLANG_RC=$?
echo "CLANG_RC=$CLANG_RC"

echo
echo "--- 5. CREATE TEST SOURCE ---"

cat > "$TESTDIR/test.c" <<'SRC'
#include <stdio.h>

int main(void) {
    return 0;
}
SRC

echo "SOURCE_CREATED=$([ -f "$TESTDIR/test.c" ] && echo YES || echo NO)"

echo
echo "--- 6. COMPILE ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -c "$TESTDIR/test.c" \
    -o "$TESTDIR/test.o" \
    2>&1

COMPILE_RC=$?

echo "COMPILE_RC=$COMPILE_RC"

if [ -f "$TESTDIR/test.o" ]; then
    echo "OBJECT_CREATED=YES"
    file "$TESTDIR/test.o"
else
    echo "OBJECT_CREATED=NO"
fi

echo
echo "--- 7. CORRECT BUILTINS CHECK ---"

if [ -f "$BUILTINS" ]; then
    echo "BUILTINS_EXISTS=YES"
else
    echo "BUILTINS_EXISTS=NO"
fi

echo
echo "--- 8. DIRECT LLD FULL LINK ---"

if [ -f "$TESTDIR/test.o" ] && \
   [ -f "$BUILTINS" ] && \
   [ -f "$CRTBEGIN" ] && \
   [ -f "$CRTEND" ]; then

    "$RUNNER" "$BOX64" "$LLD" \
        -m aarch64linux \
        -pie \
        -dynamic-linker /system/bin/linker64 \
        -z now \
        -z relro \
        -z max-page-size=16384 \
        -o "$TESTDIR/direct_full" \
        "$CRTBEGIN" \
        "$TESTDIR/test.o" \
        "$BUILTINS" \
        -l:libunwind.a \
        -ldl \
        -lc \
        "$CRTEND" \
        2>&1

    DIRECT_FULL_RC=$?
else
    echo "SKIPPED: required files missing"
    DIRECT_FULL_RC=99
fi

echo "DIRECT_FULL_RC=$DIRECT_FULL_RC"

if [ -f "$TESTDIR/direct_full" ]; then
    echo "DIRECT_FULL_CREATED=YES"
    file "$TESTDIR/direct_full"
else
    echo "DIRECT_FULL_CREATED=NO"
fi

echo
echo "--- 9. EXACT CLANG DRIVER LINK ---"

if [ -f "$TESTDIR/test.o" ]; then

    "$RUNNER" "$BOX64" "$CLANG" \
        --target=aarch64-linux-android21 \
        --sysroot="$SYSROOT" \
        -fuse-ld=lld \
        -rtlib=compiler-rt \
        -unwindlib=libunwind \
        -Wl,-z,max-page-size=16384 \
        "$TESTDIR/test.o" \
        -o "$TESTDIR/clang_full" \
        2>&1

    CLANG_LINK_RC=$?
else
    echo "SKIPPED: object missing"
    CLANG_LINK_RC=99
fi

echo "CLANG_LINK_RC=$CLANG_LINK_RC"

if [ -f "$TESTDIR/clang_full" ]; then
    echo "CLANG_FULL_CREATED=YES"
    file "$TESTDIR/clang_full"
else
    echo "CLANG_FULL_CREATED=NO"
fi

echo
echo "--- 10. CLANG VERBOSE LINK TRACE ---"

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
        -o "$TESTDIR/clang_verbose" \
        2>&1 | tee "$TESTDIR/clang_verbose.log"

    TRACE_RC=${PIPESTATUS[0]}
else
    TRACE_RC=99
fi

echo "TRACE_RC=$TRACE_RC"

echo
echo "--- 11. RESULT FILES ---"
find "$TESTDIR" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort

echo
echo "--- 12. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "BOX64_RC=$BOX64_RC"
echo "CLANG_RC=$CLANG_RC"
echo "BUILTINS_EXISTS=$([ -f "$BUILTINS" ] && echo YES || echo NO)"
echo "UNWIND_EXISTS=$([ -f "$UNWIND" ] && echo YES || echo NO)"
echo "CRTBEGIN_EXISTS=$([ -f "$CRTBEGIN" ] && echo YES || echo NO)"
echo "CRTEND_EXISTS=$([ -f "$CRTEND" ] && echo YES || echo NO)"
echo "LIBC_EXISTS=$([ -f "$LIBC" ] && echo YES || echo NO)"
echo "LIBDL_EXISTS=$([ -f "$LIBDL" ] && echo YES || echo NO)"
echo "COMPILE_RC=$COMPILE_RC"
echo "DIRECT_FULL_RC=$DIRECT_FULL_RC"
echo "CLANG_LINK_RC=$CLANG_LINK_RC"
echo "TRACE_RC=$TRACE_RC"

echo
echo "=================================================="
echo " PHASE 185 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TESTDIR"
echo "RESULT_FILE=$HOME/pocket_pcr_studio/phase185_result.txt"
echo "=================================================="
