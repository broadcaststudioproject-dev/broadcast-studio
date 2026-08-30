#!/data/data/com.termux/files/usr/bin/bash

set +e

echo "=================================================="
echo " PHASE 203: CMAKE NDK CLANG WRAPPER TEST"
echo "=================================================="

ROOT="$HOME/pocket_pcr_studio"
TESTDIR="$ROOT/phase203_test"
SRC="$TESTDIR/src"
BUILD="$TESTDIR/build"

NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
RUNNER="$PREFIX/bin/glibc-runner"
BOX64="$PREFIX/glibc/bin/box64"

rm -rf "$TESTDIR"
mkdir -p "$SRC" "$BUILD"

echo
echo "--- 1. TOOLS ---"
echo "NDK=$NDK"
echo "CLANG=$PRE/bin/clang"
echo "LLD=$PRE/bin/ld.lld"

echo
echo "--- 2. VERIFY ---"
[ -x "$RUNNER" ] && echo "RUNNER=YES" || echo "RUNNER=NO"
[ -x "$BOX64" ] && echo "BOX64=YES" || echo "BOX64=NO"
[ -f "$PRE/bin/clang" ] && echo "NDK_CLANG=YES" || echo "NDK_CLANG=NO"
[ -f "$PRE/bin/ld.lld" ] && echo "NDK_LLD=YES" || echo "NDK_LLD=NO"

echo
echo "--- 3. CLANG WRAPPER ---"

cat > "$TESTDIR/clang-wrapper" <<EOF2
#!/data/data/com.termux/files/usr/bin/bash
exec "$RUNNER" "$BOX64" "$PRE/bin/clang" "\$@"
EOF2

chmod +x "$TESTDIR/clang-wrapper"

echo "CLANG_WRAPPER=$TESTDIR/clang-wrapper"

echo
echo "--- 4. LLD WRAPPER ---"

cat > "$TESTDIR/ld-wrapper" <<EOF2
#!/data/data/com.termux/files/usr/bin/bash
exec "$RUNNER" "$BOX64" "$PRE/bin/ld.lld" "\$@"
EOF2

chmod +x "$TESTDIR/ld-wrapper"

echo "LD_WRAPPER=$TESTDIR/ld-wrapper"

echo
echo "--- 5. TEST SOURCE ---"

cat > "$SRC/main.c" <<'EOF2'
int main(void) {
    return 0;
}
EOF2

cat > "$SRC/CMakeLists.txt" <<EOF2
cmake_minimum_required(VERSION 3.22)

project(phase203 C)

add_executable(phase203 main.c)

target_link_options(phase203 PRIVATE
    -fuse-ld=$TESTDIR/ld-wrapper
    -nostdlib
    -nostartfiles
    -Wl,-e,main
)
EOF2

echo "SOURCE=YES"

echo
echo "--- 6. CMAKE CONFIGURE ---"

cmake \
  -S "$SRC" \
  -B "$BUILD" \
  -G Ninja \
  -DCMAKE_SYSTEM_NAME=Android \
  -DCMAKE_SYSTEM_VERSION=21 \
  -DANDROID_PLATFORM=android-21 \
  -DANDROID_ABI=arm64-v8a \
  -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
  -DCMAKE_ANDROID_NDK="$NDK" \
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
  -DCMAKE_C_COMPILER="$TESTDIR/clang-wrapper" \
  -DCMAKE_C_COMPILER_WORKS=1 \
  2>&1 | tee "$TESTDIR/configure.log"

CONFIGURE_RC=${PIPESTATUS[0]}

echo "CONFIGURE_RC=$CONFIGURE_RC"

echo
echo "--- 7. BUILD ---"

if [ "$CONFIGURE_RC" -eq 0 ]; then
    cmake --build "$BUILD" --verbose 2>&1 | tee "$TESTDIR/build.log"
    BUILD_RC=${PIPESTATUS[0]}
else
    BUILD_RC=99
fi

echo "BUILD_RC=$BUILD_RC"

echo
echo "--- 8. EXECUTABLE ---"

if [ -f "$BUILD/phase203" ]; then
    echo "EXECUTABLE=CREATED"
    file "$BUILD/phase203"
else
    echo "EXECUTABLE=NOT_CREATED"
fi

echo
echo "--- 9. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "CONFIGURE_RC=$CONFIGURE_RC"
echo "BUILD_RC=$BUILD_RC"

if [ -f "$BUILD/phase203" ]; then
    echo "CMAKE_CLANG_WRAPPER=SUCCESS"
else
    echo "CMAKE_CLANG_WRAPPER=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 203 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TESTDIR"
echo "RESULT_FILE=$ROOT/phase203_result.txt"
echo "=================================================="
