#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 172: BOX64 + GLIBC RUNNER DIAGNOSTIC"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"
BOX64="$GLIBC/bin/box64"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
CLANG="$X86/bin/clang"
CLANGXX="$X86/bin/clang++"

echo
echo "--- 1. HOST ---"
uname -m
getprop ro.product.cpu.abi 2>/dev/null || true

echo
echo "--- 2. GLIBC RUNNER ---"
command -v glibc-runner 2>&1 || true
which glibc-runner 2>/dev/null || true

echo
echo "--- 3. GLIBC RUNNER FILE ---"
RUNNER="$(command -v glibc-runner 2>/dev/null || true)"
if [ -n "$RUNNER" ]; then
    ls -l "$RUNNER"
    file "$RUNNER" 2>&1
    head -40 "$RUNNER" 2>/dev/null || true
else
    echo "glibc-runner NOT FOUND"
fi

echo
echo "--- 4. BOX64 FILE ---"
ls -l "$BOX64" 2>&1
file "$BOX64" 2>&1

echo
echo "--- 5. BOX64 NEEDED LIBRARIES ---"
readelf -d "$BOX64" 2>/dev/null | grep -E 'NEEDED|RPATH|RUNPATH' || true

echo
echo "--- 6. GLIBC libc.so ---"
ls -l "$GLIBC/lib/libc.so" "$GLIBC/lib/libc.so.6" 2>&1

echo
echo "--- 7. libc.so FILE TYPES ---"
file "$GLIBC/lib/libc.so" 2>&1
file "$GLIBC/lib/libc.so.6" 2>&1

echo
echo "--- 8. libc.so HEADER ---"
head -20 "$GLIBC/lib/libc.so" 2>/dev/null || true

echo
echo "--- 9. GLIBC LOADER ---"
ls -l "$GLIBC/lib/ld-linux-aarch64.so.1" 2>&1
file "$GLIBC/lib/ld-linux-aarch64.so.1" 2>&1

echo
echo "--- 10. BOX64 VERSION DIRECT ---"
"$BOX64" --version 2>&1
echo "BOX64_DIRECT_RC=$?"

echo
echo "--- 11. GLIBC RUNNER + BOX64 ---"
if [ -n "$RUNNER" ]; then
    "$RUNNER" "$BOX64" --version 2>&1
    echo "RUNNER_BOX64_RC=$?"
else
    echo "SKIPPED: glibc-runner unavailable"
fi

echo
echo "--- 12. BOX64 ENVIRONMENT ---"
env | grep -E '^(LD_LIBRARY_PATH|BOX64|GLIBC|PREFIX|PATH)=' | sort || true

echo
echo "--- 13. X86_64 CLANG ---"
readlink -f "$CLANG"
file "$(readlink -f "$CLANG")" 2>&1

echo
echo "--- 14. GLIBC X86_64 DIRECTORY CONTENT ---"
find "$GLIBC/lib/box64-x86_64-linux-gnu" \
    -maxdepth 1 -type f -o -type l \
    2>/dev/null | head -40

echo
echo "--- 15. BOX64 CONFIG ---"
find "$PREFIX" "$HOME" \
    -maxdepth 5 \
    -type f \
    \( -name 'box64rc' -o -name 'box64.conf' -o -name '.box64rc' \) \
    2>/dev/null | head -50

echo
echo "--- 16. FINAL ---"
echo "HOST=$(uname -m)"
echo "GLIBC=$GLIBC"
echo "BOX64=$BOX64"
echo "RUNNER=${RUNNER:-missing}"
echo "CLANG=$(readlink -f "$CLANG" 2>/dev/null || echo missing)"

echo
echo "=================================================="
echo " END PHASE 172"
echo "=================================================="
