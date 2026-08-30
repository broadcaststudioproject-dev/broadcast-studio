#!/data/data/com.termux/files/usr/bin/bash

set +e

echo "=================================================="
echo "PHASE 219: ROBUST CMAKE ANDROID AARCH64 TEST"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

CLANG="$PREFIX/bin/clang"
TARGET="aarch64-linux-android21"
SYSROOT="$PRE/sysroot"

TEST="$HOME/pocket_pcr_studio/phase219_test"
SRC="$TEST/src"
BUILD="$TEST/build"

rm -rf "$TEST"
mkdir -p "$SRC" "$BUILD"

echo
echo "--- 1. TOOLS ---"

echo "CLANG=$CLANG"
echo "TARGET=$TARGET"
echo "SYSROOT=$SYSROOT"

test -x "$CLANG" && echo "CLANG_EXECUTABLE=YES" || echo "CLANG_EXECUTABLE=NO"
test -d "$SYSROOT" && echo "SYSROOT_EXISTS=YES" || echo "SYSROOT_EXISTS=NO"

echo
echo "--- 2. SOURCE ---"

cat > "$SRC/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)

project(Phase219Test C)

add_executable(phase219_test main.c)
CMAKE

cat > "$SRC/main.c" <<'C'
int main(void) {
    return 0;
}
C

echo "SOURCE=YES"

echo
echo "--- 3. CMAKE CONFIGURE ---"

cmake \
  -S "$SRC" \
  -B "$BUILD" \
  -G Ninja \
  -DCMAKE_C_COMPILER="$CLANG" \
  -DCMAKE_C_COMPILER_TARGET="$TARGET" \
  -DCMAKE_SYSROOT="$SYSROOT" \
  -DCMAKE_EXE_LINKER_FLAGS="-unwindlib=none" \
  2>&1 | tee "$TEST/configure.log"

CONFIGURE_RC=${PIPESTATUS[0]}

echo
echo "CONFIGURE_RC=$CONFIGURE_RC"

echo
echo "--- 4. CACHE ---"

if [ -f "$BUILD/CMakeCache.txt" ]; then

    echo "CACHE=YES"

    grep -E \
      'CMAKE_C_COMPILER:|CMAKE_C_COMPILER_TARGET:|CMAKE_SYSROOT:|CMAKE_EXE_LINKER_FLAGS:' \
      "$BUILD/CMakeCache.txt" || true

else

    echo "CACHE=NO"

fi

echo
echo "--- 5. BUILD ---"

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
echo "--- 6. EXECUTABLE ---"

EXEC="$BUILD/phase219_test"

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
echo "--- 7. LIBUNWIND ---"

grep -n -E \
  'libunwind|-unwindlib|unwind' \
  "$TEST/configure.log" \
  "$TEST/build.log" 2>/dev/null || true

echo
echo "--- 8. RESULT ---"

if [ "$CONFIGURE_RC" -eq 0 ] && \
   [ "$BUILD_RC" -eq 0 ] && \
   [ -f "$EXEC" ]; then

    echo "PHASE219=SUCCESS"

else

    echo "PHASE219=FAILED"

fi

echo
echo "=================================================="
echo "PHASE 219 COMPLETE"
echo "=================================================="

echo "TESTDIR=$TEST"
echo "CONFIGURE_LOG=$TEST/configure.log"
echo "BUILD_LOG=$TEST/build.log"
