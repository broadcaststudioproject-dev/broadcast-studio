#!/data/data/com.termux/files/usr/bin/bash

ROOT="$HOME/pocket_pcr_studio"
TEST="$ROOT/phase208_test"
SRC="$TEST/src"
BUILD="$TEST/build"

NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

RUNNER="$PREFIX/bin/glibc-runner"
BOX64="$PREFIX/glibc/bin/box64"

rm -rf "$TEST"
mkdir -p "$SRC" "$BUILD"

echo "=================================================="
echo " PHASE 208: CMAKE NATIVE CLANG + DIRECT NDK LLD"
echo "=================================================="

cat > "$TEST/ld-wrapper" <<EOF2
#!/data/data/com.termux/files/usr/bin/bash
exec "$RUNNER" "$BOX64" "$PRE/bin/ld.lld" "\$@"
EOF2

chmod +x "$TEST/ld-wrapper"

cat > "$SRC/main.c" <<'EOF2'
int main(void)
{
    return 0;
}
EOF2

cat > "$SRC/CMakeLists.txt" <<EOF2
cmake_minimum_required(VERSION 3.22)

project(phase208 C)

add_executable(phase208 main.c)

target_link_options(phase208 PRIVATE
    -nostdlib
    -nostartfiles
    -Wl,-e,main
    -fuse-ld=$TEST/ld-wrapper
)
EOF2

echo
echo "--- 1. TOOLS ---"
echo "NATIVE_CLANG=$(command -v clang)"
echo "NDK_SYSROOT=$PRE/sysroot"
echo "LLD_WRAPPER=$TEST/ld-wrapper"

echo
echo "--- 2. CONFIGURE ---"

cmake \
  -S "$SRC" \
  -B "$BUILD" \
  -G Ninja \
  -DCMAKE_SYSTEM_NAME=Android \
  -DCMAKE_SYSTEM_VERSION=21 \
  -DANDROID_PLATFORM=android-21 \
  -DANDROID_ABI=arm64-v8a \
  -DCMAKE_C_COMPILER="$PREFIX/bin/clang" \
  -DCMAKE_C_COMPILER_TARGET=aarch64-linux-android21 \
  -DCMAKE_SYSROOT="$PRE/sysroot" \
  -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=$TEST/ld-wrapper" \
  2>&1 | tee "$TEST/configure.log"

CONFIGURE_RC=${PIPESTATUS[0]}

echo "CONFIGURE_RC=$CONFIGURE_RC"

echo
echo "--- 3. BUILD ---"

if [ "$CONFIGURE_RC" -eq 0 ]; then
    cmake --build "$BUILD" --verbose \
      2>&1 | tee "$TEST/build.log"

    BUILD_RC=${PIPESTATUS[0]}
else
    BUILD_RC=99
fi

echo "BUILD_RC=$BUILD_RC"

echo
echo "--- 4. EXECUTABLE ---"

if [ -f "$BUILD/phase208" ]; then
    echo "EXECUTABLE=CREATED"
    file "$BUILD/phase208"
else
    echo "EXECUTABLE=NOT_CREATED"
fi

echo
echo "--- 5. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "CONFIGURE_RC=$CONFIGURE_RC"
echo "BUILD_RC=$BUILD_RC"

if [ -f "$BUILD/phase208" ]; then
    echo "CMAKE_DIRECT_LLD=SUCCESS"
else
    echo "CMAKE_DIRECT_LLD=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 208 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TEST"
echo "RESULT_FILE=$ROOT/phase208_result.txt"
echo "=================================================="
