#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 171: COMPLETE X86_64 RUNTIME DIAGNOSTIC"
echo "=================================================="

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
LLVM="$NDK/toolchains/llvm"
X86="$LLVM/prebuilt/linux-x86_64"

CLANG="$X86/bin/clang"
CLANGXX="$X86/bin/clang++"

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"
BOX64="$GLIBC/bin/box64"
QEMU="$(command -v qemu-x86_64 2>/dev/null || true)"

echo
echo "--- 1. HOST ---"
uname -m
getprop ro.product.cpu.abi 2>/dev/null || true
getprop ro.product.cpu.abilist 2>/dev/null || true

echo
echo "--- 2. NDK ---"
echo "NDK=$NDK"
ls -ld "$NDK" 2>&1
echo "NDK_VERSION:"
grep -E 'Pkg\.Revision|Pkg\.Desc' \
    "$NDK/source.properties" 2>/dev/null || true

echo
echo "--- 3. X86_64 TOOLCHAIN ---"
echo "X86=$X86"
ls -ld "$X86" 2>&1
echo "CLANG=$CLANG"
readlink -f "$CLANG" 2>&1
file "$(readlink -f "$CLANG")" 2>&1

echo
echo "--- 4. CLANG INTERPRETER ---"
readelf -l "$(readlink -f "$CLANG")" 2>/dev/null \
    | grep -i interpreter || true

echo
echo "--- 5. TERMUX NATIVE CLANG ---"
command -v clang
clang --version 2>&1 | head -3

echo
echo "--- 6. QEMU ---"
echo "QEMU=$QEMU"

if [ -n "$QEMU" ]; then
    "$QEMU" --version 2>&1 | head -3
else
    echo "QEMU NOT FOUND"
fi

echo
echo "--- 7. GLIBC ---"
echo "GLIBC=$GLIBC"
ls -ld "$GLIBC" 2>&1

echo
echo "--- 8. GLIBC ARCHITECTURE ---"
if [ -f "$GLIBC/lib/libc.so.6" ]; then
    file "$GLIBC/lib/libc.so.6"
else
    echo "libc.so.6 NOT FOUND"
fi

echo
echo "--- 9. GLIBC LOADER SEARCH ---"
find "$GLIBC" -type f \
    \( -name 'ld-linux-x86-64.so.2' \
    -o -name 'ld-linux-x86-64.so.1' \
    -o -name 'ld-x86-64.so.2' \
    -o -name 'ld-musl-x86_64.so.1' \) \
    2>/dev/null | head -50

echo
echo "--- 10. BOX64 ---"
echo "BOX64=$BOX64"

if [ -f "$BOX64" ]; then
    file "$BOX64"
    readelf -l "$BOX64" 2>/dev/null \
        | grep -i interpreter || true
else
    echo "BOX64 NOT FOUND"
fi

echo
echo "--- 11. BOX64 LIBRARY DIRECTORIES ---"
find "$GLIBC/lib" -maxdepth 2 -type d \
    \( -name '*x86_64*' -o -name '*i386*' \) \
    -print 2>/dev/null

echo
echo "--- 12. X86_64 LIBC SEARCH ---"
find "$GLIBC" "$PREFIX" "$NDK" \
    -type f \
    \( -name 'libc.so.6' \
    -o -name 'ld-linux-x86-64.so.2' \) \
    2>/dev/null | head -100

echo
echo "--- 13. QEMU + NDK CLANG ---"

if [ -n "$QEMU" ]; then
    "$QEMU" "$CLANG" --version 2>&1 | head -10
    RC=${PIPESTATUS[0]}
    echo "QEMU_CLANG_RC=$RC"
else
    echo "SKIPPED: QEMU unavailable"
fi

echo
echo "--- 14. BOX64 + NDK CLANG ---"

if [ -f "$BOX64" ]; then
    "$BOX64" "$CLANG" --version 2>&1 | head -10
    RC=${PIPESTATUS[0]}
    echo "BOX64_CLANG_RC=$RC"
else
    echo "SKIPPED: BOX64 unavailable"
fi

echo
echo "--- 15. BOX64 ENVIRONMENT ---"
env | grep -E \
    '^(BOX64|GLIBC|LD_LIBRARY_PATH|PATH)=' \
    | sort || true

echo
echo "--- 16. JNI CMAKE DIRECTORIES ---"

JNI="$HOME/.pub-cache/hosted/pub.dev/jni-1.0.3/android"

if [ -d "$JNI" ]; then
    echo "JNI=$JNI"
    find "$JNI" -maxdepth 5 -type f \
        \( -name CMakeCache.txt \
        -o -name CMakeError.log \
        -o -name CMakeOutput.log \) \
        -print 2>/dev/null
else
    echo "JNI directory NOT FOUND"
fi

echo
echo "--- 17. CMAKE COMPILER CACHE ---"

find "$JNI" -name CMakeCache.txt -type f 2>/dev/null \
| while read -r CACHE; do
    echo
    echo "CACHE=$CACHE"

    grep -E \
        'CMAKE_(C|CXX)_COMPILER|CMAKE_SYSTEM_NAME|CMAKE_HOST_SYSTEM_NAME|CMAKE_HOST_SYSTEM_PROCESSOR' \
        "$CACHE" 2>/dev/null || true
done

echo
echo "--- 18. FINAL STATUS ---"

echo "HOST_ARCH=$(uname -m)"
echo "NDK_CLANG=$(readlink -f "$CLANG" 2>/dev/null || echo missing)"
echo "QEMU=${QEMU:-missing}"
echo "BOX64=$BOX64"

echo
echo "=================================================="
echo " END PHASE 171"
echo "=================================================="
