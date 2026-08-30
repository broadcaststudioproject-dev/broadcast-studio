#!/data/data/com.termux/files/usr/bin/bash
set +e

echo "=================================================="
echo "PHASE 221: FIND NDK LIBUNWIND + C++ LINK TEST"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

CLANGXX="$PREFIX/bin/clang++"
TARGET="aarch64-linux-android21"
SYSROOT="$PRE/sysroot"

TEST="$HOME/pocket_pcr_studio/phase221_test"
SRC="$TEST/src"
BUILD="$TEST/build"

rm -rf "$TEST"
mkdir -p "$SRC" "$BUILD"

echo
echo "--- 1. ENVIRONMENT ---"

echo "CLANGXX=$CLANGXX"
echo "TARGET=$TARGET"
echo "SYSROOT=$SYSROOT"
echo "NDK=$NDK"

test -x "$CLANGXX" && echo "CLANGXX_EXECUTABLE=YES" || echo "CLANGXX_EXECUTABLE=NO"
test -d "$SYSROOT" && echo "SYSROOT_EXISTS=YES" || echo "SYSROOT_EXISTS=NO"

echo
echo "--- 2. FIND LIBUNWIND ---"

find "$NDK" -type f \
  \( -name 'libunwind.a' -o -name 'libunwind.so' \) \
  -print 2>/dev/null | tee "$TEST/libunwind_paths.txt"

echo
echo "--- 3. FIND LIBC++ ---"

find "$NDK" -type f \
  \( -name 'libc++.a' -o -name 'libc++.so' \) \
  -print 2>/dev/null | head -50 | tee "$TEST/libcxx_paths.txt"

echo
echo "--- 4. SOURCE ---"

cat > "$SRC/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)

project(Phase221Test CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(phase221_test main.cpp)
CMAKE

cat > "$SRC/main.cpp" <<'CPP'
#include <iostream>
#include <string>

int main() {
    std::string message = "Phase 221 C++ unwind test";
    std::cout << message << std::endl;
    return 0;
}
CPP

echo "SOURCE=YES"

echo
echo "--- 5. CMAKE CONFIGURE ---"

cmake \
  -S "$SRC" \
  -B "$BUILD" \
  -G Ninja \
  -DCMAKE_CXX_COMPILER="$CLANGXX" \
  -DCMAKE_CXX_COMPILER_TARGET="$TARGET" \
  -DCMAKE_SYSROOT="$SYSROOT" \
  -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
  2>&1 | tee "$TEST/configure.log"

CONFIGURE_RC=${PIPESTATUS[0]}

echo
echo "CONFIGURE_RC=$CONFIGURE_RC"

echo
echo "--- 6. BUILD WITHOUT MANUAL UNWIND FLAG ---"

if [ "$CONFIGURE_RC" -eq 0 ]; then

    cmake \
      --build "$BUILD" \
      --verbose \
      2>&1 | tee "$TEST/build.log"

    BUILD_RC=${PIPESTATUS[0]}

else

    echo "BUILD_SKIPPED=CONFIGURE_FAILED"
    BUILD_RC=99

fi

echo
echo "BUILD_RC=$BUILD_RC"

echo
echo "--- 7. EXECUTABLE ---"

EXEC="$BUILD/phase221_test"

if [ -f "$EXEC" ]; then

    echo "EXECUTABLE=CREATED"

    file "$EXEC"

    echo
    "$PREFIX/bin/llvm-readelf" -h "$EXEC" 2>/dev/null | \
      grep -E 'Class:|OS/ABI:|Type:|Machine:|Entry point:' || true

    echo
    echo "--- NEEDED ---"

    "$PREFIX/bin/llvm-readelf" -d "$EXEC" 2>/dev/null | \
      grep NEEDED || true

else

    echo "EXECUTABLE=NOT_CREATED"

fi

echo
echo "--- 8. UNWIND ERRORS ---"

grep -n -E \
  '_Unwind_|libunwind|unwind|undefined symbol' \
  "$TEST/build.log" 2>/dev/null || true

echo
echo "--- 9. RESULT ---"

if [ "$CONFIGURE_RC" -eq 0 ] && \
   [ "$BUILD_RC" -eq 0 ] && \
   [ -f "$EXEC" ]; then

    echo "PHASE221=SUCCESS"

else

    echo "PHASE221=FAILED"

fi

echo
echo "=================================================="
echo "PHASE 221 COMPLETE"
echo "=================================================="

echo "TESTDIR=$TEST"
echo "LIBUNWIND_PATHS=$TEST/libunwind_paths.txt"
echo "LIBCXX_PATHS=$TEST/libcxx_paths.txt"
echo "CONFIGURE_LOG=$TEST/configure.log"
echo "BUILD_LOG=$TEST/build.log"

