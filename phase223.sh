#!/data/data/com.termux/files/usr/bin/bash
set +e

echo "=================================================="
echo "PHASE 223: NDK C++ ABI + UNWIND SYMBOL ANALYSIS"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
SYSROOT="$PRE/sysroot"

CLANG="$PREFIX/bin/clang"
CLANGXX="$PREFIX/bin/clang++"

TARGET="aarch64-linux-android21"

TEST="$HOME/pocket_pcr_studio/phase223_test"

rm -rf "$TEST"
mkdir -p "$TEST"

echo
echo "--- 1. ENVIRONMENT ---"

echo "CLANG=$CLANG"
echo "CLANGXX=$CLANGXX"
echo "TARGET=$TARGET"
echo "SYSROOT=$SYSROOT"
echo "NDK=$NDK"

echo
echo "--- 2. FIND LIBC++ABI ---"

find "$NDK" \
  -type f \
  \( -name 'libc++abi.a' -o \
     -name 'libc++abi.so' \) \
  2>/dev/null | \
  tee "$TEST/libcxxabi_paths.txt"

echo
echo "--- 3. FIND ANDROID AARCH64 C++ LIBRARIES ---"

find "$SYSROOT/usr/lib/aarch64-linux-android" \
  -type f \
  \( -name 'libc++*' -o \
     -name 'libunwind*' \) \
  2>/dev/null | \
  tee "$TEST/android_cxx_libs.txt"

echo
echo "--- 4. LIBC++ABI SYMBOL CHECK ---"

ABI_FILES=$(find "$NDK" \
  -type f \
  \( -name 'libc++abi.a' -o -name 'libc++abi.so' \) \
  2>/dev/null)

for F in $ABI_FILES; do
    echo
    echo "FILE=$F"

    if command -v llvm-nm >/dev/null 2>&1; then
        llvm-nm "$F" 2>/dev/null | \
          grep -E '_Unwind_|__cxa|__gxx_personality' | \
          head -80 || true
    fi
done

echo
echo "--- 5. LIBC++_SHARED SYMBOL CHECK ---"

SHARED_FILES=$(find "$SYSROOT/usr/lib/aarch64-linux-android" \
  -type f \
  -name 'libc++_shared.so' \
  2>/dev/null)

for F in $SHARED_FILES; do
    echo
    echo "FILE=$F"

    "$PREFIX/bin/llvm-readelf" -Ws "$F" 2>/dev/null | \
      grep -E '_Unwind_|__cxa|personality' | \
      head -100 || true
done

echo
echo "--- 6. SEARCH ALL NDK AARCH64 UNWIND SYMBOLS ---"

for F in $(find "$NDK" \
  -type f \
  \( -name '*.a' -o -name '*.so' \) \
  2>/dev/null | \
  grep -E 'aarch64|android'); do

    if command -v llvm-nm >/dev/null 2>&1; then
        llvm-nm "$F" 2>/dev/null | \
          grep -q '_Unwind_Resume' && {
            echo "FOUND _Unwind_Resume IN:"
            echo "$F"
        }
    fi
done

echo
echo "--- 7. SIMPLE C++ WITHOUT EXCEPTIONS ---"

cat > "$TEST/simple.cpp" <<'CXX'
int main() {
    return 0;
}
CXX

"$CLANGXX" \
  --target="$TARGET" \
  --sysroot="$SYSROOT" \
  -stdlib=libc++ \
  -fno-exceptions \
  -fno-rtti \
  -unwindlib=none \
  "$TEST/simple.cpp" \
  -o "$TEST/simple_test" \
  2>&1 | tee "$TEST/simple_build.log"

SIMPLE_RC=${PIPESTATUS[0]}

echo
echo "SIMPLE_RC=$SIMPLE_RC"

if [ -f "$TEST/simple_test" ]; then
    echo "SIMPLE_EXECUTABLE=CREATED"

    file "$TEST/simple_test"

    "$PREFIX/bin/llvm-readelf" -d "$TEST/simple_test" 2>/dev/null | \
      grep NEEDED || true
else
    echo "SIMPLE_EXECUTABLE=NOT_CREATED"
fi

echo
echo "--- 8. C++ WITH EXCEPTIONS + UNWINDLIB NONE ---"

cat > "$TEST/exceptions.cpp" <<'CXX'
#include <stdexcept>

int main() {
    try {
        throw std::runtime_error("test");
    } catch (...) {
        return 0;
    }

    return 1;
}
CXX

"$CLANGXX" \
  --target="$TARGET" \
  --sysroot="$SYSROOT" \
  -stdlib=libc++ \
  -unwindlib=none \
  "$TEST/exceptions.cpp" \
  -o "$TEST/exceptions_test" \
  2>&1 | tee "$TEST/exceptions_build.log"

EXC_RC=${PIPESTATUS[0]}

echo
echo "EXCEPTIONS_RC=$EXC_RC"

if [ -f "$TEST/exceptions_test" ]; then
    echo "EXCEPTIONS_EXECUTABLE=CREATED"
else
    echo "EXCEPTIONS_EXECUTABLE=NOT_CREATED"
fi

echo
echo "--- 9. C++ WITH EXCEPTIONS + DEFAULT UNWIND ---"

"$CLANGXX" \
  --target="$TARGET" \
  --sysroot="$SYSROOT" \
  -stdlib=libc++ \
  "$TEST/exceptions.cpp" \
  -o "$TEST/exceptions_default_test" \
  2>&1 | tee "$TEST/exceptions_default_build.log"

DEFAULT_RC=${PIPESTATUS[0]}

echo
echo "DEFAULT_EXCEPTIONS_RC=$DEFAULT_RC"

if [ -f "$TEST/exceptions_default_test" ]; then
    echo "DEFAULT_EXCEPTIONS_EXECUTABLE=CREATED"
else
    echo "DEFAULT_EXCEPTIONS_EXECUTABLE=NOT_CREATED"
fi

echo
echo "--- 10. RESULTS ---"

echo "SIMPLE_RC=$SIMPLE_RC"
echo "EXCEPTIONS_RC=$EXC_RC"
echo "DEFAULT_EXCEPTIONS_RC=$DEFAULT_RC"

echo
echo "=================================================="
echo "PHASE 223 COMPLETE"
echo "=================================================="

echo "TESTDIR=$TEST"
echo "LIBCXXABI_PATHS=$TEST/libcxxabi_paths.txt"
echo "ANDROID_CXX_LIBS=$TEST/android_cxx_libs.txt"
echo "SIMPLE_LOG=$TEST/simple_build.log"
echo "EXCEPTIONS_LOG=$TEST/exceptions_build.log"
echo "DEFAULT_LOG=$TEST/exceptions_default_build.log"

