#!/data/data/com.termux/files/usr/bin/bash

set +e

echo "=================================================="
echo "PHASE 225: LIBC++ABI + STATIC UNWIND SYMBOL TEST"
echo "=================================================="
echo

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
PREBUILT="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
SYSROOT="$PREBUILT/sysroot"

CLANGXX="$PREFIX/bin/clang++"
TARGET="aarch64-linux-android21"

TEST="$PWD/phase225_test"

rm -rf "$TEST"
mkdir -p "$TEST/src" "$TEST/build"

echo "--- 1. ENVIRONMENT ---"
echo "CLANGXX=$CLANGXX"
echo "TARGET=$TARGET"
echo "SYSROOT=$SYSROOT"
echo

echo "--- 2. C++ RUNTIME FILES ---"

find "$SYSROOT/usr/lib/aarch64-linux-android" \
  -maxdepth 1 -type f \
  \( -name 'libc++abi*' -o -name 'libc++_static*' -o -name 'libc++_shared*' \) \
  -print | tee "$TEST/cxx_runtime_files.txt"

echo

LIBCXXABI="$SYSROOT/usr/lib/aarch64-linux-android/libc++abi.a"
LIBCXXSTATIC="$SYSROOT/usr/lib/aarch64-linux-android/libc++_static.a"
LIBCXXSHARED="$SYSROOT/usr/lib/aarch64-linux-android/libc++_shared.so"

echo "--- 3. SELECTED FILES ---"
echo "LIBCXXABI=$LIBCXXABI"
echo "LIBCXXSTATIC=$LIBCXXSTATIC"
echo "LIBCXXSHARED=$LIBCXXSHARED"
echo

echo "--- 4. LIBC++ABI _Unwind_Resume ---"

if [ -f "$LIBCXXABI" ]; then
    llvm-nm -A -C "$LIBCXXABI" 2>/dev/null |
        grep -E '_Unwind_Resume|__gxx_personality_v0' |
        tee "$TEST/libcxxabi_symbols.txt"
else
    echo "LIBCXXABI_NOT_FOUND"
fi

echo

echo "--- 5. LIBC++ STATIC _Unwind_Resume ---"

if [ -f "$LIBCXXSTATIC" ]; then
    llvm-nm -A -C "$LIBCXXSTATIC" 2>/dev/null |
        grep -E '_Unwind_Resume|__gxx_personality_v0' |
        tee "$TEST/libcxxstatic_symbols.txt"
else
    echo "LIBCXXSTATIC_NOT_FOUND"
fi

echo

echo "--- 6. SHARED LIB SYMBOL ---"

if [ -f "$LIBCXXSHARED" ]; then
    llvm-readelf -Ws "$LIBCXXSHARED" 2>/dev/null |
        grep -E '_Unwind_Resume|__gxx_personality_v0' |
        tee "$TEST/libcxxshared_symbols.txt"
else
    echo "LIBCXXSHARED_NOT_FOUND"
fi

echo

echo "--- 7. TEST SOURCE ---"

cat > "$TEST/src/main.cpp" <<'CPP'
#include <iostream>
#include <string>

int main() {
    std::string s = "PHASE225";
    std::cout << s << std::endl;
    return 0;
}
CPP

cat > "$TEST/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)

project(phase225_test LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(phase225_test src/main.cpp)

target_compile_options(phase225_test PRIVATE
    -stdlib=libc++
)

target_link_options(phase225_test PRIVATE
    -stdlib=libc++
    -unwindlib=none
)
CMAKE

echo "SOURCE=YES"
echo

echo "--- 8. SYMBOL BINDING CLASSIFICATION ---"

for F in \
    "$TEST/libcxxabi_symbols.txt" \
    "$TEST/libcxxstatic_symbols.txt" \
    "$TEST/libcxxshared_symbols.txt"
do
    echo "FILE=$F"

    if [ -f "$F" ]; then
        grep '_Unwind_Resume' "$F" 2>/dev/null
    fi

    echo
done

echo "--- 9. CMAKE CONFIGURE ---"

cmake -S "$TEST" \
      -B "$TEST/build" \
      -G Ninja \
      -DCMAKE_CXX_COMPILER="$CLANGXX" \
      -DCMAKE_CXX_COMPILER_TARGET="$TARGET" \
      -DCMAKE_SYSROOT="$SYSROOT" \
      -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
      2>&1 | tee "$TEST/configure.log"

CONFIGURE_RC=${PIPESTATUS[0]}

echo "CONFIGURE_RC=$CONFIGURE_RC"
echo

echo "--- 10. DRIVER LINK TRACE ---"

"$CLANGXX" \
    --target="$TARGET" \
    --sysroot="$SYSROOT" \
    -stdlib=libc++ \
    -unwindlib=none \
    -### \
    "$TEST/src/main.cpp" \
    -o "$TEST/driver_test" \
    2>&1 | tee "$TEST/driver_link_trace.txt"

echo

echo "--- 11. RESULT ---"

if [ "$CONFIGURE_RC" -eq 0 ]; then

    cmake --build "$TEST/build" \
        --verbose \
        2>&1 | tee "$TEST/build.log"

    BUILD_RC=${PIPESTATUS[0]}

else

    BUILD_RC=99
    echo "BUILD_SKIPPED=CONFIGURE_FAILED"
fi

echo "BUILD_RC=$BUILD_RC"
echo

if [ -f "$TEST/build/phase225_test" ]; then
    echo "EXECUTABLE=CREATED"
    file "$TEST/build/phase225_test"
else
    echo "EXECUTABLE=NOT_CREATED"
fi

echo

echo "--- 12. KEY ERRORS ---"

grep -R -E \
    'undefined symbol|unable to find|_Unwind_Resume|linker command failed' \
    "$TEST" 2>/dev/null |
    tee "$TEST/key_errors.txt"

echo

echo "=================================================="
echo "PHASE 225 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TEST"
echo "LIBCXXABI_SYMBOLS=$TEST/libcxxabi_symbols.txt"
echo "LIBCXXSTATIC_SYMBOLS=$TEST/libcxxstatic_symbols.txt"
echo "LIBCXXSHARED_SYMBOLS=$TEST/libcxxshared_symbols.txt"
echo "DRIVER_TRACE=$TEST/driver_link_trace.txt"
echo "BUILD_LOG=$TEST/build.log"
echo "=================================================="

