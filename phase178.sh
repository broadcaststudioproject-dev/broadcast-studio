#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 178: NDK LIBXML2 + BOX64 HOST RUNTIME TEST"
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
HOSTLIB="$GLIBC/lib/box64-x86_64-linux-gnu"

TESTDIR="$HOME/pocket_pcr_studio/phase178_test"
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
echo "NDKLIB=$NDKLIB"
echo "NDKXML=$NDKXML"
echo "HOSTLIB=$HOSTLIB"

echo
echo "--- 2. NDK LIBXML2 FILE ---"
if [ -f "$NDKXML" ]; then
    ls -l "$NDKXML"
    file "$NDKXML" 2>&1
else
    echo "NDK libxml2.so.2 NOT FOUND"
fi

echo
echo "--- 3. NDK LIBXML2 ELF HEADER ---"
if [ -f "$NDKXML" ]; then
    readelf -h "$NDKXML" 2>/dev/null | \
        grep -E 'Class:|Machine:|Type:|OS/ABI:' || true
fi

echo
echo "--- 4. NDK LIBXML2 NEEDED LIBRARIES ---"
if [ -f "$NDKXML" ]; then
    readelf -d "$NDKXML" 2>/dev/null | \
        grep -E 'NEEDED|RPATH|RUNPATH|SONAME' || true
fi

echo
echo "--- 5. NDK LIBXML2 SYMBOL CHECK ---"
if [ -f "$NDKXML" ]; then
    readelf -Ws "$NDKXML" 2>/dev/null | \
        grep -E 'xmlCheckVersion|xmlInitParser|xmlFree' | \
        head -20 || true
fi

echo
echo "--- 6. ALL NDK HOST LIBRARIES ---"
find "$NDKLIB" -maxdepth 1 \
    \( -type f -o -type l \) \
    -printf '%f\n' 2>/dev/null | sort | head -150

echo
echo "--- 7. BOX64 X86_64 LIBRARY DIRECTORY ---"
if [ -d "$HOSTLIB" ]; then
    find "$HOSTLIB" -maxdepth 1 \
        \( -type f -o -type l \) \
        -printf '%f\n' 2>/dev/null | sort
else
    echo "BOX64 X86_64 LIBRARY DIRECTORY NOT FOUND"
fi

echo
echo "--- 8. CHECK LIBXML2 IN BOX64 DIRECTORY ---"
find "$HOSTLIB" \
    -maxdepth 1 \
    \( -name 'libxml2.so*' -o -name 'libxml2.so' \) \
    -print 2>/dev/null || true

echo
echo "--- 9. TEMPORARY TEST LIBRARY PATH ---"
TESTLIB="$TESTDIR/lib"
mkdir -p "$TESTLIB"

rm -f "$TESTLIB/libxml2.so.2"

if [ -f "$NDKXML" ]; then
    ln -s "$NDKXML" "$TESTLIB/libxml2.so.2"
    ls -l "$TESTLIB/libxml2.so.2"
else
    echo "Cannot create temporary libxml2 link"
fi

echo
echo "--- 10. BOX64 VERSION ---"
"$RUNNER" "$BOX64" --version 2>&1
echo "BOX64_RC=$?"

echo
echo "--- 11. BOX64 + LIBXML2 DIRECT LOAD TEST ---"

cat > "$TESTDIR/xmltest.c" <<'SRC'
#include <stdio.h>
#include <dlfcn.h>

int main(void)
{
    const char *path = "libxml2.so.2";

    void *h = dlopen(path, RTLD_NOW);

    if (!h) {
        printf("DLOPEN_FAILED\n");
        printf("ERROR=%s\n", dlerror());
        return 1;
    }

    printf("DLOPEN_SUCCESS\n");

    dlclose(h);

    return 0;
}
SRC

echo "SOURCE:"
cat "$TESTDIR/xmltest.c"

echo
echo "--- 12. COMPILE HOST TEST PROGRAM ---"

NATIVE_CLANG="$(command -v clang)"

echo "NATIVE_CLANG=$NATIVE_CLANG"

"$NATIVE_CLANG" \
    "$TESTDIR/xmltest.c" \
    -ldl \
    -o "$TESTDIR/xmltest" \
    2>&1

NATIVE_COMPILE_RC=$?

echo "NATIVE_COMPILE_RC=$NATIVE_COMPILE_RC"

if [ -f "$TESTDIR/xmltest" ]; then
    file "$TESTDIR/xmltest"
else
    echo "HOST TEST PROGRAM NOT CREATED"
fi

echo
echo "--- 13. RUN HOST TEST THROUGH GLIBC RUNNER + BOX64 ---"

if [ -f "$TESTDIR/xmltest" ]; then

    echo "TEST WITHOUT LIBRARY PATH:"

    "$RUNNER" "$BOX64" "$TESTDIR/xmltest" 2>&1

    RC=$?

    echo "NO_LIBPATH_RC=$RC"

    echo
    echo "TEST WITH NDK LIBRARY PATH:"

    LD_LIBRARY_PATH="$TESTLIB:$NDKLIB:$HOSTLIB" \
    "$RUNNER" "$BOX64" "$TESTDIR/xmltest" 2>&1

    RC=$?

    echo "NDK_LIBPATH_RC=$RC"

else
    echo "SKIPPED: test executable missing"
fi

echo
echo "--- 14. BOX64 LIBRARY SEARCH ENVIRONMENT ---"

echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-<empty>}"

echo
echo "--- 15. CLANG HOST FILE ---"

readlink -f "$CLANG" 2>/dev/null || true
file "$(readlink -f "$CLANG")" 2>&1

echo
echo "--- 16. CLANG HOST NEEDED LIBRARIES ---"

CLANG_REAL="$(readlink -f "$CLANG" 2>/dev/null || echo "$CLANG")"

readelf -d "$CLANG_REAL" 2>/dev/null | \
    grep -E 'NEEDED|RPATH|RUNPATH' || true

echo
echo "--- 17. CLANG LIBXML DEPENDENCY SEARCH ---"

find "$NDK" "$PREFIX" "$GLIBC" \
    -type f \
    \( -name 'libxml2.so.2' \
    -o -name 'libxml2.so.2.*' \) \
    2>/dev/null | head -100

echo
echo "--- 18. LIBXML ARCHITECTURE SUMMARY ---"

for F in \
    "$NDKXML" \
    "$PREFIX/lib/libxml2.so.16.1.3"
do
    if [ -f "$F" ]; then
        echo
        echo "FILE=$F"
        file "$F" 2>&1
        readelf -h "$F" 2>/dev/null | \
            grep -E 'Class:|Machine:|Type:' || true
    fi
done

echo
echo "--- 19. IMPORTANT: NO SYSTEM CHANGES ---"
echo "Only temporary test directory was created:"
echo "$TESTDIR"

echo
echo "--- 20. FINAL STATUS ---"

echo "HOST=$HOST"
echo "NDKXML_EXISTS=$([ -f "$NDKXML" ] && echo YES || echo NO)"
echo "TEST_PROGRAM=$([ -f "$TESTDIR/xmltest" ] && echo YES || echo NO)"
echo "NATIVE_COMPILE_RC=$NATIVE_COMPILE_RC"

echo
echo "=================================================="
echo " END PHASE 178"
echo "=================================================="

