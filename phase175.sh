#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 175: NDK LLD LINKER ISOLATION TEST"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"

RUNNER="$(command -v glibc-runner)"
BOX64="$GLIBC/bin/box64"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

CLANG="$X86/bin/clang"
CLANGXX="$X86/bin/clang++"
LLD="$X86/bin/ld.lld"

TESTDIR="$PWD/phase174_test"

echo
echo "--- 1. TOOLS ---"
echo "RUNNER=$RUNNER"
echo "BOX64=$BOX64"
echo "CLANG=$CLANG"
echo "CLANGXX=$CLANGXX"
echo "LLD=$LLD"

echo
echo "--- 2. LLD FILE ---"

ls -l "$LLD" 2>&1
file "$LLD" 2>&1

echo
echo "--- 3. LLD INTERPRETER ---"

readelf -l "$LLD" 2>/dev/null | grep -i interpreter || true

echo
echo "--- 4. LLD VERSION THROUGH RUNNER ---"

"$RUNNER" "$BOX64" "$LLD" --version 2>&1

LLD_VERSION_RC=${PIPESTATUS[0]}

echo "LLD_VERSION_RC=$LLD_VERSION_RC"

echo
echo "--- 5. LLD NEEDED LIBRARIES ---"

readelf -d "$LLD" 2>/dev/null |
grep -E 'NEEDED|RPATH|RUNPATH' || true

echo
echo "--- 6. BOX64 X86_64 LIBRARIES ---"

X86LIB="$GLIBC/lib/box64-x86_64-linux-gnu"

echo "X86LIB=$X86LIB"

ls -la "$X86LIB" 2>&1 | head -80

echo
echo "--- 7. LIBC / LIBDL / LIBM SEARCH ---"

find "$X86LIB" "$GLIBC" \
    -maxdepth 3 \
    -type f \
    \( -name 'libc.so*' \
       -o -name 'libdl.so*' \
       -o -name 'libm.so*' \
       -o -name 'libpthread.so*' \
       -o -name 'librt.so*' \
       -o -name 'libgcc_s.so*' \) \
    2>/dev/null | head -100

echo
echo "--- 8. EXISTING ARM64 OBJECT ---"

OBJ="$TESTDIR/test.o"

ls -l "$OBJ" 2>&1

file "$OBJ" 2>&1

readelf -h "$OBJ" 2>/dev/null |
grep -E 'Class|Machine|Type' || true

echo
echo "--- 9. NDK CRT FILES ---"

find "$X86/sysroot" \
    -type f \
    \( -name 'crtbegin_dynamic.o' \
       -o -name 'crtend_android.o' \
       -o -name 'crtbegin_so.o' \
       -o -name 'crtend_so.o' \) \
    2>/dev/null | head -30

echo
echo "--- 10. ANDROID ARM64 LIBRARY PATH ---"

find "$X86/sysroot/usr/lib/aarch64-linux-android" \
    -maxdepth 2 \
    -type f \
    2>/dev/null | head -40

echo
echo "--- 11. CLANG PRINT SEARCH DIRS ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    -print-search-dirs 2>&1

echo
echo "--- 12. CLANG LINKER NAME ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    -### \
    "$OBJ" \
    -o "$TESTDIR/test_trace" \
    2>&1 | head -100

echo
echo "--- 13. DIRECT LLD ARM64 LINK TEST ---"

"$RUNNER" "$BOX64" "$LLD" \
    -flavor gnu \
    "$OBJ" \
    -o "$TESTDIR/direct_lld_test" \
    2>&1

DIRECT_LLD_RC=${PIPESTATUS[0]}

echo "DIRECT_LLD_RC=$DIRECT_LLD_RC"

if [ -f "$TESTDIR/direct_lld_test" ]; then
    echo "DIRECT_LLD_CREATED=YES"
    file "$TESTDIR/direct_lld_test"
else
    echo "DIRECT_LLD_CREATED=NO"
fi

echo
echo "--- 14. CLANG LINK TEST WITH VERBOSE ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    -v \
    "$OBJ" \
    -o "$TESTDIR/test_verbose" \
    2>&1 | head -150

CLANG_LINK_RC=${PIPESTATUS[0]}

echo "CLANG_LINK_RC=$CLANG_LINK_RC"

if [ -f "$TESTDIR/test_verbose" ]; then
    echo "CLANG_LINK_CREATED=YES"
    file "$TESTDIR/test_verbose"
else
    echo "CLANG_LINK_CREATED=NO"
fi

echo
echo "--- 15. BOX64 ENVIRONMENT ---"

env | grep -E \
'^(BOX64|LD_LIBRARY_PATH|GLIBC|PREFIX|PATH)=' |
sort || true

echo
echo "--- 16. FINAL ---"

echo "HOST=$(uname -m)"
echo "LLD_VERSION_RC=$LLD_VERSION_RC"
echo "DIRECT_LLD_RC=$DIRECT_LLD_RC"
echo "CLANG_LINK_RC=$CLANG_LINK_RC"

echo
echo "=================================================="
echo " END PHASE 175"
echo "=================================================="

