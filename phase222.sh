#!/data/data/com.termux/files/usr/bin/bash
set +e

echo "=================================================="
echo "PHASE 222: ANDROID AARCH64 C++ LIBRARY SEARCH MAP"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

CLANG="$PREFIX/bin/clang"
CLANGXX="$PREFIX/bin/clang++"
TARGET="aarch64-linux-android21"
SYSROOT="$PRE/sysroot"

TEST="$HOME/pocket_pcr_studio/phase222_test"

rm -rf "$TEST"
mkdir -p "$TEST"

echo
echo "--- 1. ENVIRONMENT ---"

echo "CLANG=$CLANG"
echo "CLANGXX=$CLANGXX"
echo "TARGET=$TARGET"
echo "SYSROOT=$SYSROOT"
echo "NDK=$NDK"
echo "PRE=$PRE"

echo
echo "--- 2. CLANG RESOURCE DIR ---"

"$CLANG" --target="$TARGET" --print-resource-dir 2>&1 | tee "$TEST/resource_dir.txt"

echo
echo "--- 3. CLANG SEARCH DIRS ---"

"$CLANG" --target="$TARGET" --sysroot="$SYSROOT" \
  --print-search-dirs 2>&1 | tee "$TEST/search_dirs.txt"

echo
echo "--- 4. ANDROID AARCH64 SYSROOT LIBRARIES ---"

find "$SYSROOT/usr/lib" \
  -maxdepth 3 \
  -type f \
  \( -name 'libc++.a' -o \
     -name 'libc++.so' -o \
     -name 'libc++_shared.so' -o \
     -name 'libunwind.a' -o \
     -name 'libunwind.so' \) \
  2>/dev/null | \
  grep -E 'aarch64|arm64|android' | \
  tee "$TEST/android_aarch64_libs.txt"

echo
echo "--- 5. ALL NDK LIBUNWIND PATHS ---"

find "$NDK" \
  -type f \
  \( -name 'libunwind.a' -o -name 'libunwind.so' \) \
  2>/dev/null | \
  tee "$TEST/all_libunwind.txt"

echo
echo "--- 6. ALL ANDROID AARCH64 LIBC++ PATHS ---"

find "$NDK" \
  -type f \
  \( -name 'libc++.a' -o -name 'libc++.so' -o -name 'libc++_shared.so' \) \
  2>/dev/null | \
  grep -E 'aarch64|android' | \
  tee "$TEST/all_aarch64_libcxx.txt"

echo
echo "--- 7. EXPECTED TARGET DIRECTORY ---"

for D in \
  "$SYSROOT/usr/lib/aarch64-linux-android/21" \
  "$SYSROOT/usr/lib/aarch64-linux-android/24" \
  "$SYSROOT/usr/lib/aarch64-linux-android/28" \
  "$SYSROOT/usr/lib/aarch64-linux-android/34" \
  "$SYSROOT/usr/lib/aarch64-linux-android/35"
do
    if [ -d "$D" ]; then
        echo "DIR_EXISTS=$D"
        ls -la "$D" 2>/dev/null | \
          grep -E 'libc\+\+|libunwind|libc\.so|libdl'
    else
        echo "DIR_MISSING=$D"
    fi
done

echo
echo "--- 8. CLANG++ VERBOSE LINK SEARCH ---"

cat > "$TEST/test.cpp" <<'CXX'
#include <iostream>

int main() {
    std::cout << "phase222" << std::endl;
    return 0;
}
CXX

"$CLANGXX" \
  --target="$TARGET" \
  --sysroot="$SYSROOT" \
  -stdlib=libc++ \
  -### \
  "$TEST/test.cpp" \
  -o "$TEST/phase222_test" \
  2>&1 | tee "$TEST/clangxx_driver.txt"

echo
echo "--- 9. DIRECT LIBUNWIND TEST ---"

"$CLANG" \
  --target="$TARGET" \
  --sysroot="$SYSROOT" \
  -print-file-name=libunwind.a \
  2>&1 | tee "$TEST/print_libunwind.txt"

echo
echo "--- 10. DIRECT LIBC++ TEST ---"

"$CLANGXX" \
  --target="$TARGET" \
  --sysroot="$SYSROOT" \
  -stdlib=libc++ \
  -print-file-name=libc++.a \
  2>&1 | tee "$TEST/print_libcxx.txt"

echo
echo "--- 11. DIRECT LIBC++ SHARED TEST ---"

"$CLANGXX" \
  --target="$TARGET" \
  --sysroot="$SYSROOT" \
  -stdlib=libc++ \
  -print-file-name=libc++_shared.so \
  2>&1 | tee "$TEST/print_libcxx_shared.txt"

echo
echo "--- 12. SUMMARY ---"

echo "libunwind:"
cat "$TEST/print_libunwind.txt"

echo
echo "libc++.a:"
cat "$TEST/print_libcxx.txt"

echo
echo "libc++_shared.so:"
cat "$TEST/print_libcxx_shared.txt"

echo
echo "=================================================="
echo "PHASE 222 COMPLETE"
echo "=================================================="

echo "TESTDIR=$TEST"
echo "RESOURCE_DIR=$TEST/resource_dir.txt"
echo "SEARCH_DIRS=$TEST/search_dirs.txt"
echo "ANDROID_AARCH64_LIBS=$TEST/android_aarch64_libs.txt"
echo "ALL_LIBUNWIND=$TEST/all_libunwind.txt"
echo "ALL_AARCH64_LIBCXX=$TEST/all_aarch64_libcxx.txt"
echo "CLANGXX_DRIVER=$TEST/clangxx_driver.txt"

