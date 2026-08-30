#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 179: BOX64 + NDK CLANG LIBXML2 RUNTIME"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

RUNNER="$(command -v glibc-runner 2>/dev/null || true)"
BOX64="$GLIBC/bin/box64"

CLANG="$X86/bin/clang"
CLANGXX="$X86/bin/clang++"
LLD="$X86/bin/ld.lld"

NDKLIB="$X86/lib"
NDKXML="$NDKLIB/libxml2.so.2"
X86LIB="$GLIBC/lib/box64-x86_64-linux-gnu"

TESTDIR="$HOME/pocket_pcr_studio/phase179_test"
mkdir -p "$TESTDIR"

echo
echo "--- 1. ENVIRONMENT ---"
echo "HOST=$(uname -m)"
echo "PREFIX=$PREFIX"
echo "GLIBC=$GLIBC"
echo "RUNNER=$RUNNER"
echo "BOX64=$BOX64"
echo "NDK=$NDK"
echo "X86=$X86"
echo "CLANG=$CLANG"
echo "LLD=$LLD"
echo "NDKLIB=$NDKLIB"
echo "NDKXML=$NDKXML"
echo "X86LIB=$X86LIB"

echo
echo "--- 2. NDK LIBXML2 ---"

if [ -f "$NDKXML" ]; then
    ls -l "$NDKXML"
    file "$NDKXML" 2>&1
    readelf -h "$NDKXML" 2>/dev/null | \
        grep -E 'Class:|Type:|Machine:' || true
else
    echo "ERROR: NDK libxml2.so.2 NOT FOUND"
fi

echo
echo "--- 3. NDK LIBXML2 NEEDED ---"

if [ -f "$NDKXML" ]; then
    readelf -d "$NDKXML" 2>/dev/null | \
        grep -E 'NEEDED|SONAME|RPATH|RUNPATH' || true
fi

echo
echo "--- 4. BOX64 X86_64 LIBXML2 ---"

find "$X86LIB" \
    -maxdepth 1 \
    \( -name 'libxml2.so*' -o -name 'libxml2.so' \) \
    -ls 2>/dev/null || true

echo
echo "--- 5. BOX64 VERSION ---"

"$RUNNER" "$BOX64" --version 2>&1
BOX64_RC=$?

echo "BOX64_RC=$BOX64_RC"

echo
echo "--- 6. CLANG VERSION THROUGH BOX64 ---"

"$RUNNER" "$BOX64" "$CLANG" --version 2>&1

CLANG_VERSION_RC=$?

echo "CLANG_VERSION_RC=$CLANG_VERSION_RC"

echo
echo "--- 7. CLANG PRINT RESOURCE DIR ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --print-resource-dir 2>&1

RESOURCE_RC=$?

echo "RESOURCE_RC=$RESOURCE_RC"

echo
echo "--- 8. CLANG PRINT SEARCH DIRS ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --print-search-dirs 2>&1

SEARCHDIR_RC=$?

echo "SEARCHDIR_RC=$SEARCHDIR_RC"

echo
echo "--- 9. CLANG DRIVER VERBOSE WITHOUT INPUT ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    -v -E -x c /dev/null \
    2>&1 | head -80

DRIVER_RC=${PIPESTATUS[0]}

echo "DRIVER_RC=$DRIVER_RC"

echo
echo "--- 10. CREATE SIMPLE SOURCE ---"

cat > "$TESTDIR/test.c" <<'SRC'
int main(void)
{
    return 0;
}
SRC

ls -l "$TESTDIR/test.c"
file "$TESTDIR/test.c"

echo
echo "--- 11. COMPILE ONLY THROUGH BOX64 ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    -c "$TESTDIR/test.c" \
    -o "$TESTDIR/test.o" \
    2>&1

COMPILE_RC=$?

echo "COMPILE_RC=$COMPILE_RC"

if [ -f "$TESTDIR/test.o" ]; then
    echo "OBJECT_CREATED=YES"
    file "$TESTDIR/test.o"
    readelf -h "$TESTDIR/test.o" 2>/dev/null | \
        grep -E 'Class:|Type:|Machine:' || true
else
    echo "OBJECT_CREATED=NO"
fi

echo
echo "--- 12. CLANG LINKER DRIVER TRACE ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    -### \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/test_link" \
    2>&1

TRACE_RC=$?

echo "TRACE_RC=$TRACE_RC"

echo
echo "--- 13. EXTRACT LIBXML2 FROM TRACE ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    -### \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/test_link" \
    2>&1 | \
    grep -iE 'libxml|ld\.lld|clang_rt|libunwind|/lib/|sysroot' \
    | head -100 || true

echo
echo "--- 14. LINK TEST WITH EMPTY ENVIRONMENT ---"

env -i \
    PATH="$PREFIX/bin:$PREFIX/glibc/bin" \
    HOME="$HOME" \
    PREFIX="$PREFIX" \
    "$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/test_empty_env" \
    2>&1

EMPTY_LINK_RC=$?

echo "EMPTY_LINK_RC=$EMPTY_LINK_RC"

echo
echo "--- 15. LINK TEST WITH NDK LIBRARY PATH ---"

LD_LIBRARY_PATH="$NDKLIB:$X86LIB" \
"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/test_ndk_libpath" \
    2>&1

NDK_LINK_RC=$?

echo "NDK_LINK_RC=$NDK_LINK_RC"

echo
echo "--- 16. LINK TEST WITH BOX64 LIBRARY PATH ---"

LD_LIBRARY_PATH="$X86LIB:$NDKLIB" \
"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/test_box64_libpath" \
    2>&1

BOX64_LINK_RC=$?

echo "BOX64_LINK_RC=$BOX64_LINK_RC"

echo
echo "--- 17. LINK TEST WITH BOTH LIBRARY PATHS ---"

LD_LIBRARY_PATH="$X86LIB:$NDKLIB:$GLIBC/lib" \
"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/test_both_libpath" \
    2>&1

BOTH_LINK_RC=$?

echo "BOTH_LINK_RC=$BOTH_LINK_RC"

echo
echo "--- 18. CREATED EXECUTABLES ---"

for F in \
    "$TESTDIR/test_empty_env" \
    "$TESTDIR/test_ndk_libpath" \
    "$TESTDIR/test_box64_libpath" \
    "$TESTDIR/test_both_libpath"
do
    if [ -f "$F" ]; then
        echo "CREATED: $F"
        file "$F"
    else
        echo "NOT_CREATED: $F"
    fi
done

echo
echo "--- 19. NDK CLANG HOST NEEDED LIBRARIES ---"

CLANG_REAL="$(readlink -f "$CLANG" 2>/dev/null || echo "$CLANG")"

echo "CLANG_REAL=$CLANG_REAL"

readelf -d "$CLANG_REAL" 2>/dev/null | \
    grep -E 'NEEDED|SONAME|RPATH|RUNPATH' || true

echo
echo "--- 20. SEARCH FOR LIBXML2 ---"

echo "NDK:"
find "$NDK" \
    -type f \
    \( -name 'libxml2.so.2' -o -name 'libxml2.so.2.*' \) \
    2>/dev/null | head -30

echo
echo "PREFIX:"
find "$PREFIX" \
    -type f \
    \( -name 'libxml2.so.2' -o -name 'libxml2.so.2.*' \) \
    2>/dev/null | head -30

echo
echo "--- 21. LIBUNWIND SEARCH ---"

find "$NDK" "$PREFIX" \
    -type f \
    \( -name 'libunwind.so*' -o -name 'libunwind.a' \) \
    2>/dev/null | head -50

echo
echo "--- 22. BUILTINS SEARCH ---"

find "$X86" \
    -type f \
    -name 'libclang_rt.builtins-aarch64-android.a' \
    2>/dev/null | head -20

echo
echo "--- 23. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "BOX64_RC=$BOX64_RC"
echo "CLANG_VERSION_RC=$CLANG_VERSION_RC"
echo "RESOURCE_RC=$RESOURCE_RC"
echo "SEARCHDIR_RC=$SEARCHDIR_RC"
echo "DRIVER_RC=$DRIVER_RC"
echo "COMPILE_RC=$COMPILE_RC"
echo "TRACE_RC=$TRACE_RC"
echo "EMPTY_LINK_RC=$EMPTY_LINK_RC"
echo "NDK_LINK_RC=$NDK_LINK_RC"
echo "BOX64_LINK_RC=$BOX64_LINK_RC"
echo "BOTH_LINK_RC=$BOTH_LINK_RC"

echo
echo "=================================================="
echo " PHASE 179 COMPLETE"
echo "=================================================="

echo
echo "TESTDIR=$TESTDIR"
echo "RESULT_FILE=$HOME/pocket_pcr_studio/phase179_result.txt"

