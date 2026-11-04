#!/data/data/com.termux/files/usr/bin/bash

set +e

echo "=================================================="
echo " PHASE 188: DIRECT LLD CMAKE LINKER WORKAROUND"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"
RUNNER="$(command -v glibc-runner)"
BOX64="$GLIBC/bin/box64"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

BIN="$X86/bin"
SYSROOT="$X86/sysroot"
RESOURCE="$X86/lib/clang/19"
RESLIB="$RESOURCE/lib/linux"

CLANG="$BIN/clang"
LLD="$BIN/ld.lld"

TESTDIR="$HOME/pocket_pcr_studio/phase188_test"

rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"

echo
echo "--- 1. TOOLCHAIN ---"
echo "HOST=$(uname -m)"
echo "RUNNER=$RUNNER"
echo "BOX64=$BOX64"
echo "CLANG=$CLANG"
echo "LLD=$LLD"
echo "SYSROOT=$SYSROOT"

echo
echo "--- 2. VERIFY BOX64 + LLD ---"

"$RUNNER" "$BOX64" "$LLD" --version 2>&1
LLD_RC=$?

echo "LLD_RC=$LLD_RC"

echo
echo "--- 3. CREATE DIRECT-LD WRAPPER ---"

cat > "$TESTDIR/android-ld-wrapper" <<'WRAP'
#!/data/data/com.termux/files/usr/bin/bash

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"
RUNNER="$PREFIX/bin/glibc-runner"
BOX64="$GLIBC/bin/box64"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

LLD="$X86/bin/ld.lld"

exec "$RUNNER" "$BOX64" "$LLD" "$@"
WRAP

chmod +x "$TESTDIR/android-ld-wrapper"

echo "WRAPPER_CREATED=YES"
file "$TESTDIR/android-ld-wrapper"

echo
echo "--- 4. TEST WRAPPER ---"

"$TESTDIR/android-ld-wrapper" --version 2>&1
WRAPPER_RC=$?

echo "WRAPPER_RC=$WRAPPER_RC"

echo
echo "--- 5. CREATE C SOURCE ---"

cat > "$TESTDIR/test.c" <<'SRC'
int main(void) {
    return 0;
}
SRC

echo
echo "--- 6. CLANG COMPILE ONLY ---"

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
echo "--- 7. DIRECT LLD LINK USING WR

cat > phase188.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set +e

echo "=================================================="
echo " PHASE 188: DIRECT LLD ANDROID LINK WORKAROUND"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"
RUNNER="$PREFIX/bin/glibc-runner"
BOX64="$GLIBC/bin/box64"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

BIN="$X86/bin"
SYSROOT="$X86/sysroot"
RESOURCE="$X86/lib/clang/19"
RESLIB="$RESOURCE/lib/linux"
LIBDIR="$SYSROOT/usr/lib/aarch64-linux-android/21"

CLANG="$BIN/clang"
LLD="$BIN/ld.lld"

BUILTINS="$RESLIB/libclang_rt.builtins-aarch64-android.a"
CRTBEGIN="$LIBDIR/crtbegin_dynamic.o"
CRTEND="$LIBDIR/crtend_android.o"
LIBC="$LIBDIR/libc.so"
LIBDL="$LIBDIR/libdl.so"

TESTDIR="$HOME/pocket_pcr_studio/phase188_test"

rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"

echo
echo "--- 1. TOOLCHAIN ---"
echo "HOST=$(uname -m)"
echo "RUNNER=$RUNNER"
echo "BOX64=$BOX64"
echo "CLANG=$CLANG"
echo "LLD=$LLD"
echo "SYSROOT=$SYSROOT"
echo "LIBDIR=$LIBDIR"

echo
echo "--- 2. VERIFY FILES ---"

for F in \
    "$RUNNER" \
    "$BOX64" \
    "$CLANG" \
    "$LLD" \
    "$SYSROOT" \
    "$BUILTINS" \
    "$CRTBEGIN" \
    "$CRTEND" \
    "$LIBC" \
    "$LIBDL"
do
    if [ -e "$F" ]; then
        echo "FOUND=$F"
    else
        echo "MISSING=$F"
    fi
done

echo
echo "--- 3. BOX64 ---"

"$RUNNER" "$BOX64" --version 2>&1
BOX64_RC=$?

echo "BOX64_RC=$BOX64_RC"

echo
echo "--- 4. LLD VERSION ---"

"$RUNNER" "$BOX64" "$LLD" --version 2>&1
LLD_VERSION_RC=$?

echo "LLD_VERSION_RC=$LLD_VERSION_RC"

echo
echo "--- 5. CREATE SOURCE ---"

cat > "$TESTDIR/test.c" <<'SRC'
int main(void)
{
    return 0;
}
SRC

echo "SOURCE_CREATED=YES"

echo
echo "--- 6. CLANG COMPILE ONLY ---"

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
echo "--- 7. DIRECT LLD LINK ---"

"$RUNNER" "$BOX64" "$LLD" \
    -m aarch64linux \
    -pie \
    -e main \
    -dynamic-linker /system/bin/linker64 \
    -z max-page-size=16384 \
    "$CRTBEGIN" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    "$LIBC" \
    "$LIBDL" \
    "$CRTEND" \
    -o "$TESTDIR/direct_link" \
    2>&1

DIRECT_RC=$?

echo "DIRECT_RC=$DIRECT_RC"

if [ -f "$TESTDIR/direct_link" ]; then
    echo "DIRECT_LINK_CREATED=YES"
    file "$TESTDIR/direct_link"
else
    echo "DIRECT_LINK_CREATED=NO"
fi

echo
echo "--- 8. DIRECT LLD WITH LIB SEARCH PATH ---"

"$RUNNER" "$BOX64" "$LLD" \
    -m aarch64linux \
    -pie \
    -e main \
    -dynamic-linker /system/bin/linker64 \
    -z max-page-size=16384 \
    -L"$RESLIB/aarch64" \
    -L"$LIBDIR" \
    "$CRTBEGIN" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    -lunwind \
    -ldl \
    -lc \
    "$CRTEND" \
    -o "$TESTDIR/direct_search_link" \
    2>&1

SEARCH_LINK_RC=$?

echo "SEARCH_LINK_RC=$SEARCH_LINK_RC"

if [ -f "$TESTDIR/direct_search_link" ]; then
    echo "SEARCH_LINK_CREATED=YES"
    file "$TESTDIR/direct_search_link"
else
    echo "SEARCH_LINK_CREATED=NO"
fi

echo
echo "--- 9. DIRECT LLD WITHOUT LIBUNWIND ---"

"$RUNNER" "$BOX64" "$LLD" \
    -m aarch64linux \
    -pie \
    -e main \
    -dynamic-linker /system/bin/linker64 \
    -z max-page-size=16384 \
    "$CRTBEGIN" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    "$LIBC" \
    "$LIBDL" \
    "$CRTEND" \
    -o "$TESTDIR/no_unwind_link" \
    2>&1

NO_UNWIND_RC=$?

echo "NO_UNWIND_RC=$NO_UNWIND_RC"

if [ -f "$TESTDIR/no_unwind_link" ]; then
    echo "NO_UNWIND_CREATED=YES"
    file "$TESTDIR/no_unwind_link"
else
    echo "NO_UNWIND_CREATED=NO"
fi

echo
echo "--- 10. TEST DIRECT EXECUTABLE METADATA ---"

for F in \
    "$TESTDIR/direct_link" \
    "$TESTDIR/direct_search_link" \
    "$TESTDIR/no_unwind_link"
do
    if [ -f "$F" ]; then
        echo
        echo "FILE=$F"
        file "$F"
        readelf -h "$F" 2>/dev/null | grep -E \
            'Class:|Type:|Machine:|Entry point:'
        readelf -l "$F" 2>/dev/null | grep -E \
            'INTERP|LOAD|GNU_STACK' | head -10
    fi
done

echo
echo "--- 11. NEEDED LIBRARIES ---"

for F in \
    "$TESTDIR/direct_link" \
    "$TESTDIR/direct_search_link" \
    "$TESTDIR/no_unwind_link"
do
    if [ -f "$F" ]; then
        echo
        echo "NEEDED_FOR=$F"
        readelf -d "$F" 2>/dev/null | grep NEEDED
    fi
done

echo
echo "--- 12. FILE INVENTORY ---"

find "$TESTDIR" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort

echo
echo "--- 13. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "BOX64_RC=$BOX64_RC"
echo "LLD_VERSION_RC=$LLD_VERSION_RC"
echo "COMPILE_RC=$COMPILE_RC"
echo "DIRECT_RC=$DIRECT_RC"
echo "SEARCH_LINK_RC=$SEARCH_LINK_RC"
echo "NO_UNWIND_RC=$NO_UNWIND_RC"

if [ -f "$TESTDIR/direct_link" ]; then
    echo "DIRECT_LINK_STATUS=SUCCESS"
else
    echo "DIRECT_LINK_STATUS=FAILED"
fi

if [ -f "$TESTDIR/direct_search_link" ]; then
    echo "SEARCH_LINK_STATUS=SUCCESS"
else
    echo "SEARCH_LINK_STATUS=FAILED"
fi

if [ -f "$TESTDIR/no_unwind_link" ]; then
    echo "NO_UNWIND_STATUS=SUCCESS"
else
    echo "NO_UNWIND_STATUS=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 188 COMPLETE"
echo "=================================================="

echo "TESTDIR=$TESTDIR"
echo "RESULT_FILE=$HOME/pocket_pcr_studio/phase188_result.txt"

echo "=================================================="
