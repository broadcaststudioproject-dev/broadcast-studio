#!/data/data/com.termux/files/usr/bin/bash
set +e

echo "=================================================="
echo "PHASE 224: ANDROID AARCH64 C++ RUNTIME SOURCE"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
SYSROOT="$PRE/sysroot"

TEST="$HOME/pocket_pcr_studio/phase224_test"

rm -rf "$TEST"
mkdir -p "$TEST"

echo
echo "--- 1. ANDROID AARCH64 LIBRARY DIRECTORY ---"

LIBDIR="$SYSROOT/usr/lib/aarch64-linux-android"

echo "LIBDIR=$LIBDIR"

ls -lah "$LIBDIR" 2>/dev/null | \
  grep -E 'libc\+\+|unwind|compiler|c\+\+abi|c\.so|libdl|libm' \
  | tee "$TEST/android_runtime_listing.txt"

echo
echo "--- 2. API 21 LIBRARY DIRECTORY ---"

LIB21="$LIBDIR/21"

echo "LIB21=$LIB21"

ls -lah "$LIB21" 2>/dev/null | \
  grep -E 'libc\+\+|unwind|compiler|c\+\+abi' \
  | tee "$TEST/api21_runtime_listing.txt"

echo
echo "--- 3. LIBC++ SHARED ---"

find "$SYSROOT" \
  -type f \
  -name 'libc++_shared.so' \
  2>/dev/null | \
  tee "$TEST/libcxx_shared_paths.txt"

echo
echo "--- 4. READ ELF LIBC++ SHARED ---"

for F in $(cat "$TEST/libcxx_shared_paths.txt"); do
    echo
    echo "FILE=$F"

    "$PREFIX/bin/llvm-readelf" -h "$F" 2>/dev/null | \
      grep -E 'Class:|Machine:|OS/ABI:' || true

    echo "--- NEEDED ---"

    "$PREFIX/bin/llvm-readelf" -d "$F" 2>/dev/null | \
      grep NEEDED || true

    echo "--- UNWIND SYMBOLS ---"

    "$PREFIX/bin/llvm-readelf" -Ws "$F" 2>/dev/null | \
      grep -E '_Unwind_Resume|__gxx_personality|__cxa_throw' | \
      head -50 || true
done | tee "$TEST/libcxx_shared_analysis.txt"

echo
echo "--- 5. COMPILER BUILTINS ---"

find "$PREFIX/lib/clang/21" \
  -type f \
  -name '*builtins*aarch64*' \
  2>/dev/null | \
  tee "$TEST/termux_builtins.txt"

echo
echo "--- 6. NDK BUILTINS ---"

find "$PRE" \
  -type f \
  -name '*builtins*aarch64*' \
  2>/dev/null | \
  tee "$TEST/ndk_builtins.txt"

echo
echo "--- 7. ANDROID LIBC UNWIND SYMBOLS ---"

for F in \
    "$LIB21"/*.so \
    "$LIB21"/*.a \
    "$LIBDIR"/*.so \
    "$LIBDIR"/*.a; do

    [ -f "$F" ] || continue

    "$PREFIX/bin/llvm-readelf" -Ws "$F" 2>/dev/null | \
      grep -q '_Unwind_Resume' && {
        echo "FOUND _Unwind_Resume:"
        echo "$F"
    }

done | tee "$TEST/android_unwind_symbol_sources.txt"

echo
echo "--- 8. ANDROID C++ ABI SYMBOLS ---"

for F in \
    "$LIB21"/*.so \
    "$LIB21"/*.a; do

    [ -f "$F" ] || continue

    "$PREFIX/bin/llvm-readelf" -Ws "$F" 2>/dev/null | \
      grep -E '__cxa_throw|__gxx_personality|_Unwind_Resume' \
      >/dev/null 2>&1 && {

        echo
        echo "FILE=$F"

        "$PREFIX/bin/llvm-readelf" -Ws "$F" 2>/dev/null | \
          grep -E '__cxa_throw|__gxx_personality|_Unwind_Resume' \
          | head -30
    }

done | tee "$TEST/cxx_abi_symbols.txt"

echo
echo "--- 9. CLANG++ PRINT SEARCH DIRS ---"

"$PREFIX/bin/clang++" \
  --target=aarch64-linux-android21 \
  --sysroot="$SYSROOT" \
  -stdlib=libc++ \
  -### \
  -x c++ \
  -c /dev/null \
  2>&1 | tee "$TEST/clangxx_compile_driver.txt"

echo
echo "--- 10. CLANG++ PRINT LINK DRIVER ---"

cat > "$TEST/test.cpp" <<'CXX'
#include <iostream>

int main() {
    std::cout << "runtime-test";
    return 0;
}
CXX

"$PREFIX/bin/clang++" \
  --target=aarch64-linux-android21 \
  --sysroot="$SYSROOT" \
  -stdlib=libc++ \
  -### \
  "$TEST/test.cpp" \
  -o "$TEST/test" \
  2>&1 | tee "$TEST/clangxx_link_driver.txt"

echo
echo "--- 11. RESULT SUMMARY ---"

echo "LIBCXX_SHARED_COUNT=$(find "$SYSROOT" -type f -name 'libc++_shared.so' 2>/dev/null | wc -l)"
echo "TERMUX_BUILTINS_COUNT=$(wc -l < "$TEST/termux_builtins.txt" 2>/dev/null)"
echo "NDK_BUILTINS_COUNT=$(wc -l < "$TEST/ndk_builtins.txt" 2>/dev/null)"
echo "UNWIND_SYMBOL_SOURCES=$(grep -c 'FOUND _Unwind_Resume' "$TEST/android_unwind_symbol_sources.txt" 2>/dev/null)"

echo
echo "=================================================="
echo "PHASE 224 COMPLETE"
echo "=================================================="

echo "TESTDIR=$TEST"

