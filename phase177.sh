#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 177: NDK ANDROID LINK LIBRARY EXACT PATH"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

RUNNER="$(command -v glibc-runner)"
BOX64="$GLIBC/bin/box64"

echo
echo "--- 1. TOOLS ---"
echo "RUNNER=$RUNNER"
echo "BOX64=$BOX64"
echo "NDK=$NDK"
echo "X86=$X86"

echo
echo "--- 2. NDK DIRECTORY ---"
ls -ld "$NDK" 2>&1
ls -ld "$X86" 2>&1

echo
echo "--- 3. BUILTINS SEARCH ---"
find "$X86" -type f \
    -name 'libclang_rt.builtins-aarch64-android.a' \
    2>/dev/null | head -20

echo
echo "--- 4. LIBUNWIND SEARCH ---"
find "$X86" -type f \
    \( -name 'libunwind.a' -o -name 'libunwind.so*' \) \
    2>/dev/null | head -50

echo
echo "--- 5. ANDROID LIBC SEARCH ---"
find "$X86/sysroot" -type f \
    \( -name 'libc.so' -o -name 'libc++.so' -o -name 'libdl.so' \) \
    2>/dev/null | head -100

echo
echo "--- 6. AARCH64 ANDROID LIB DIRECTORY ---"
find "$X86/sysroot/usr/lib/aarch64-linux-android" \
    -maxdepth 2 -type f 2>/dev/null | head -100

echo
echo "--- 7. CRT FILES ---"
find "$X86/sysroot" -type f \
    \( -name 'crtbegin_dynamic.o' \
    -o -name 'crtend_android.o' \
    -o -name 'crtbegin_so.o' \
    -o -name 'crtend_so.o' \) \
    2>/dev/null | head -50

echo
echo "--- 8. CLANG RESOURCE TREE ---"
find "$X86/lib/clang/19" \
    -maxdepth 5 -type f 2>/dev/null | head -100

echo
echo "--- 9. LLD LOCATION ---"
LLD="$X86/bin/ld.lld"

echo "LLD=$LLD"
readlink -f "$LLD" 2>/dev/null || true
file "$(readlink -f "$LLD")" 2>&1

echo
echo "--- 10. LLD VERSION THROUGH RUNNER ---"
"$RUNNER" "$BOX64" "$LLD" --version 2>&1
echo "LLD_RC=$?"

echo
echo "--- 11. NDK TOOLCHAIN ARCHIVE SEARCH ---"
find "$X86" -type f \
    \( -name '*.a' -o -name '*.so' \) \
    2>/dev/null | grep -E \
    'builtins|unwind|libc|libdl|libm|libgcc' \
    | head -150

echo
echo "--- 12. X86_64 HOST LIBRARY CHECK ---"
find "$GLIBC/lib/box64-x86_64-linux-gnu" \
    -maxdepth 1 \
    \( -type f -o -type l \) \
    2>/dev/null | sort | head -100

echo
echo "--- 13. LIBXML CHECK ---"
find "$GLIBC" "$PREFIX" \
    -type f \
    \( -name 'libxml2.so*' -o -name 'libxml2.so.2' \) \
    2>/dev/null | head -50

echo
echo "--- 14. LIBXML NEEDED ---"
XML="$(find "$GLIBC/lib/box64-x86_64-linux-gnu" \
    -maxdepth 1 -name 'libxml2.so*' \
    2>/dev/null | head -1)"

if [ -n "$XML" ]; then
    echo "XML=$XML"
    file "$XML" 2>&1
    readelf -d "$XML" 2>/dev/null | grep NEEDED || true
else
    echo "libxml2 NOT FOUND"
fi

echo
echo "--- 15. FINAL ---"
echo "HOST=$(uname -m)"
echo "NDK=$NDK"
echo "X86=$X86"
echo "RUNNER=$RUNNER"
echo "BOX64=$BOX64"

echo
echo "=================================================="
echo " END PHASE 177"
echo "=================================================="

