#!/data/data/com.termux/files/usr/bin/bash
set +e

echo "=================================================="
echo "PHASE 220: CMAKE C++ LIBC++ + UNWINDLIB NONE"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

CLANG="$PREFIX/bin/clang"
CLANGXX="$PREFIX/bin/clang++"
TARGET="aarch64-linux-android21"
SYSROOT="$PRE/sysroot"

TEST="$HOME/pocket_pcr_studio/phase220_test"
SRC="$TEST/src"
BUILD="$TEST/build"

rm -rf "$TEST"
mkdir -p "$SRC" "$BUILD"

echo
echo "--- 1. TOOLS ---"

echo "CLANG=$CLANG"
echo "CLANGXX=$CLANGXX"
echo "TARGET=$TARGET"
echo "SYSROOT=$SYSROOT"

test -x "$CLANG" && echo "CLANG_EXECUTABLE=YES" || echo "CLANG_EXECUTABLE=NO"
test -x "$CLANGXX" && echo "CLANGXX_EXECUTABLE=YES" || echo "CLANGXX_EXECUTABLE=NO"
test -d "$SYSROOT" && echo "SYSROOT_EXISTS=YES" || echo "SYSROOT_EXISTS=NO"

echo
echo "--- 2. COMPILER VERSIONS ---"

"$CLANG" --version
echo
"$CLANGXX" --version

echo
echo "--- 3. SOURCE ---"

cat > "$SRC/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)

project(Phase220Test CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(phase220_test main.cpp)

target_link_options(phase220_test PRIVATE
    -unwindlib=none
)
CMAKE

cat > "$SRC/main.cpp" <<'CPP'
#include <iostream>
#include <string>

int main() {
    std::string message = "Phase 220 Android C++ libc++ test";
    std::cout << message << std::endl;
    return 0;
}
CPP

echo "SOURCE=YES"

echo
echo "--- 4. CMAKE CONFIGURE ---"

cmake \
  -S "$SRC" \
  -B "$BUILD" \
  -G Ninja \
  -DCMAKE_CXX_COMPILER="$CLANGXX" \
  -DCMAKE_CXX_COMPILER_TARGET="$TARGET" \
  -DCMAKE_SYSROOT="$SYSROOT" \
  -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
  -DCMAKE_EXE_LINKER_FLAGS="-unwindlib=none" \
  2>&1 | tee "$TEST/configure.log"

CONFIGURE_RC=${PIPESTATUS[0]}

echo
echo "CONFIGURE_RC=$CONFIGURE_RC"

echo
echo "--- 5. CACHE ---"

if [ -f "$BUILD/CMakeCache.txt" ]; then
    echo "CACHE=YES"

    grep -E \
      'CMAKE_CXX_COMPILER:|CMAKE_CXX_COMPILER_TARGET:|CMAKE_SYSROOT:|CMAKE_CXX_FLAGS:|CMAKE_EXE_LINKER_FLAGS:' \
      "$BUILD/CMakeCache.txt" || true
else
    echo "CACHE=NO"
fi

echo
echo "--- 6. BUILD ---"

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

EXEC="$BUILD/phase220_test"

if [ -f "$EXEC" ]; then

    echo "EXECUTABLE=CREATED"

    file "$EXEC"

    echo
    echo "--- ELF HEADER ---"

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
echo "--- 8. LIBC++ / LIBUNWIND TRACE ---"

grep -n -E \
  'libc\+\+|libc\+\+abi|libunwind|-unwindlib|unwind' \
  "$TEST/configure.log" \
  "$TEST/build.log" 2>/dev/null || true

echo
echo "--- 9. LINK COMMAND ---"

grep -n -E \
  'clang\+\+|clang|phase220_test|stdlib|unwindlib' \
  "$TEST/build.log" 2>/dev/null || true

echo
echo "--- 10. RESULT ---"

if [ "$CONFIGURE_RC" -eq 0 ] && \
   [ "$BUILD_RC" -eq 0 ] && \
   [ -f "$EXEC" ]; then

    echo "PHASE220=SUCCESS"

else

    echo "PHASE220=FAILED"

fi

echo
echo "=================================================="
echo "PHASE 220 COMPLETE"
echo "=================================================="

echo "TESTDIR=$TEST"
echo "CONFIGURE_LOG=$TEST/configure.log"
echo "BUILD_LOG=$TEST/build.log"

