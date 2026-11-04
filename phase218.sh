#!/data/data/com.termux/files/usr/bin/bash

set +e

echo "=================================================="
echo "PHASE 218: CMAKE WITH UNWINDLIB NONE"
echo "=================================================="

TEST="$HOME/pocket_pcr_studio/phase218_test"
SRC="$TEST/src"
BUILD="$TEST/build"

rm -rf "$TEST"
mkdir -p "$SRC" "$BUILD"

echo
echo "--- 1. TOOLS ---"

echo "CMAKE=$(command -v cmake)"
echo "NINJA=$(command -v ninja)"
echo "CLANG=$CLANG"
echo "CLANGXX=$CLANGXX"
echo "TARGET=$TARGET"
echo "SYSROOT=$SYSROOT"

echo
echo "--- 2. SOURCE ---"

cat > "$SRC/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)

project(Phase218Test C)

add_executable(phase218_test main.c)
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
  -DCMAKE_EXE_LINKER_FLAGS_INIT="-unwindlib=none" \
  2>&1 | tee "$TEST/configure.log"

CONFIGURE_RC=${PIPESTATUS[0]}

echo
echo "CONFIGURE_RC=$CONFIGURE_RC"

echo
echo "--- 4. CHECK CACHE ---"

if [ -f "$BUILD/CMakeCache.txt" ]; then
    echo "CACHE=YES"

    grep -E \
      'CMAKE_C_COMPILER:|CMAKE_C_COMPILER_TARGET:|CMAKE_SYSROOT:|CMAKE_EXE_LINKER_FLAGS' \
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

EXEC="$BUILD/phase218_test"

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
echo "--- 7. LIBUNWIND CHECK ---"

grep -n -E \
  'libunwind|-unwindlib|unwind' \
  "$TEST/configure.log" \
  "$TEST/build.log" 2>/dev/null || true

echo
echo "--- 8. RESULT ---"

if [ "$CONFIGURE_RC" -eq 0 ] && \
   [ "$BUILD_RC" -eq 0 ] && \
   [ -f "$EXEC" ]; then

    echo "PHASE218=SUCCESS"

else

    echo "PHASE218=FAILED"

fi

echo
echo "=================================================="
echo "PHASE 218 COMPLETE"
echo "=================================================="

echo "TESTDIR=$TEST"
echo "CONFIGURE_LOG=$TEST/configure.log"
echo "BUILD_LOG=$TEST/build.log"
