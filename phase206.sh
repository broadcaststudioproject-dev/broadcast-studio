#!/data/data/com.termux/files/usr/bin/bash

ROOT="$HOME/pocket_pcr_studio"
TEST="$ROOT/phase206_test"
SRC="$TEST/src"
BUILD="$TEST/build"

NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

RUNNER="$PREFIX/bin/glibc-runner"
BOX64="$PREFIX/glibc/bin/box64"

rm -rf "$TEST"
mkdir -p "$SRC" "$BUILD"

echo "=================================================="
echo " PHASE 206: EXPLICIT NDK TOOL WRAPPERS"
echo "=================================================="

echo
echo "--- 1. REAL TOOLS ---"

[ -f "$PRE/bin/clang" ] && echo "CLANG=YES" || echo "CLANG=NO"
[ -f "$PRE/bin/ld.lld" ] && echo "LLD=YES" || echo "LLD=NO"

echo
echo "--- 2. CREATE CLANG WRAPPER ---"

cat > "$TEST/clang-wrapper" <<EOF2
#!/data/data/com.termux/files/usr/bin/bash
exec "$RUNNER" "$BOX64" "$PRE/bin/clang" "\$@"
EOF2

chmod +x "$TEST/clang-wrapper"

echo "CLANG_WRAPPER=YES"

echo
echo "--- 3. CREATE LLD WRAPPER ---"

cat > "$TEST/ld-wrapper" <<EOF2
#!/data/data/com.termux/files/usr/bin/bash
exec "$RUNNER" "$BOX64" "$PRE/bin/ld.lld" "\$@"
EOF2

chmod +x "$TEST/ld-wrapper"

echo "LD_WRAPPER=YES"

echo
echo "--- 4. SOURCE ---"

cat > "$SRC/main.c" <<'EOF2'
int main(void)
{
    return 0;
}
EOF2

cat > "$SRC/CMakeLists.txt" <<EOF2
cmake_minimum_required(VERSION 3.22)

project(phase206 C)

add_executable(phase206 main.c)

target_link_options(phase206 PRIVATE
    -nostdlib
    -nostartfiles
    -Wl,-e,main
    -fuse-ld=$TEST/ld-wrapper
)
EOF2

echo "SOURCE=YES"

echo
echo "--- 5. CONFIGURE ---"

CC="$TEST/clang-wrapper" \
cmake \
  -S "$SRC" \
  -B "$BUILD" \
  -G Ninja \
  -DCMAKE_SYSTEM_NAME=Android \
  -DCMAKE_SYSTEM_VERSION=21 \
  -DANDROID_PLATFORM=android-21 \
  -DANDROID_ABI=arm64-v8a \
  -DCMAKE_C_COMPILER="$TEST/clang-wrapper" \
  -DCMAKE_C_COMPILER_TARGET=aarch64-linux-android21 \
  -DCMAKE_SYSROOT="$PRE/sysroot" \
  2>&1 | tee "$TEST/configure.log"

CONFIGURE_RC=${PIPESTATUS[0]}

echo "CONFIGURE_RC=$CONFIGURE_RC"

echo
echo "--- 6. BUILD ---"

if [ "$CONFIGURE_RC" -eq 0 ]; then
    cmake --build "$BUILD" --verbose \
      2>&1 | tee "$TEST/build.log"

    BUILD_RC=${PIPESTATUS[0]}
else
    BUILD_RC=99
fi

echo "BUILD_RC=$BUILD_RC"

echo
echo "--- 7. EXECUTABLE ---"

if [ -f "$BUILD/phase206" ]; then
    echo "EXECUTABLE=CREATED"
    file "$BUILD/phase206"
else
    echo "EXECUTABLE=NOT_CREATED"
fi

echo
echo "--- 8. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "CONFIGURE_RC=$CONFIGURE_RC"
echo "BUILD_RC=$BUILD_RC"

if [ -f "$BUILD/phase206" ]; then
    echo "EXPLICIT_WRAPPER_CMAKE=SUCCESS"
else
    echo "EXPLICIT_WRAPPER_CMAKE=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 206 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TEST"
echo "RESULT_FILE=$ROOT/phase206_result.txt"
echo "=================================================="
