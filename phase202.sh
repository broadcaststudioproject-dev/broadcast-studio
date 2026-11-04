#!/data/data/com.termux/files/usr/bin/bash

set +e

echo "=================================================="
echo " PHASE 202: NDK HOST TAG OVERRIDE TEST"
echo "=================================================="

ROOT="$HOME/pocket_pcr_studio"
TEST="$ROOT/phase202_test"
NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
CMAKE="$HOME/../usr/opt/android-sdk/cmake/3.22.1/bin/cmake"
TOOLCHAIN="$NDK/build/cmake/android.toolchain.cmake"

rm -rf "$TEST"
mkdir -p "$TEST/src" "$TEST/build"

echo
echo "--- 1. TOOLS ---"
echo "NDK=$NDK"
echo "CMAKE=$CMAKE"
echo "TOOLCHAIN=$TOOLCHAIN"

echo
echo "--- 2. SOURCE ---"
cat > "$TEST/src/main.c" <<'SRC'
int main(void) { return 0; }
SRC

cat > "$TEST/src/CMakeLists.txt" <<CMAKEFILE
cmake_minimum_required(VERSION 3.18)
project(phase202 C)

add_executable(phase202 main.c)
CMAKEFILE

echo "SOURCE=YES"

echo
echo "--- 3. CONFIGURE WITH EXPLICIT HOST TAG ---"

"$CMAKE" \
  -S "$TEST/src" \
  -B "$TEST/build" \
  -G Ninja \
  -DCMAKE_SYSTEM_NAME=Android \
  -DCMAKE_SYSTEM_VERSION=21 \
  -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
  -DCMAKE_ANDROID_NDK="$NDK" \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
  -DANDROID_HOST_TAG=linux-x86_64 \
  2>&1 | tee "$TEST/configure.log"

CONFIGURE_RC=${PIPESTATUS[0]}
echo "CONFIGURE_RC=$CONFIGURE_RC"

echo
echo "--- 4. COMPILER CACHE ---"
grep -E 'CMAKE_(C|CXX)_COMPILER:|ANDROID_HOST_TAG|ANDROID_TOOLCHAIN_ROOT' \
  "$TEST/build/CMakeCache.txt" 2>/dev/null

echo
echo "--- 5. BUILD ---"

if [ "$CONFIGURE_RC" -eq 0 ]; then
  "$CMAKE" --build "$TEST/build" -v 2>&1 | tee "$TEST/build.log"
  BUILD_RC=${PIPESTATUS[0]}
else
  BUILD_RC=99
fi

echo "BUILD_RC=$BUILD_RC"

echo
echo "--- 6. OUTPUT ---"
if [ -f "$TEST/build/phase202" ]; then
  echo "EXECUTABLE=CREATED"
  file "$TEST/build/phase202"
else
  echo "EXECUTABLE=NOT_CREATED"
fi

echo
echo "--- 7. FINAL STATUS ---"
echo "HOST=$(uname -m)"
echo "CONFIGURE_RC=$CONFIGURE_RC"
echo "BUILD_RC=$BUILD_RC"

if [ "$CONFIGURE_RC" -eq 0 ] && [ "$BUILD_RC" -eq 0 ]; then
  echo "HOST_TAG_OVERRIDE=SUCCESS"
else
  echo "HOST_TAG_OVERRIDE=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 202 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TEST"
echo "RESULT_FILE=$ROOT/phase202_result.txt"
echo "=================================================="
