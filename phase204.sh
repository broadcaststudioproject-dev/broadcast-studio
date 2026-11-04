#!/data/data/com.termux/files/usr/bin/bash

set +e

echo "=================================================="
echo " PHASE 204: NDK HOST-PATH SHADOW WRAPPER"
echo "=================================================="

ROOT="$HOME/pocket_pcr_studio"
TEST="$ROOT/phase204_test"
SRC="$TEST/src"
BUILD="$TEST/build"

NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
RUNNER="$PREFIX/bin/glibc-runner"
BOX64="$PREFIX/glibc/bin/box64"

rm -rf "$TEST"
mkdir -p "$SRC" "$BUILD"

echo
echo "--- 1. VERIFY REAL NDK ---"

[ -f "$PRE/bin/clang" ] && echo "REAL_CLANG=YES" || echo "REAL_CLANG=NO"
[ -f "$PRE/bin/ld.lld" ] && echo "REAL_LLD=YES" || echo "REAL_LLD=NO"

echo
echo "--- 2. CREATE SHADOW HOST ---"

SHADOW="$TEST/prebuilt/linux-x86_64"

mkdir -p "$SHADOW"

ln -s "$PRE/sysroot" "$SHADOW/sysroot"
ln -s "$PRE/lib" "$SHADOW/lib"

mkdir -p "$SHADOW/lib64"
ln -s "$PRE/lib/clang" "$SHADOW/lib/clang"

mkdir -p "$SHADOW/bin"

cat > "$SHADOW/bin/clang" <<EOF2
#!/data/data/com.termux/files/usr/bin/bash
exec "$RUNNER" "$BOX64" "$PRE/bin/clang" "\$@"
EOF2

cat > "$SHADOW/bin/ld.lld" <<EOF2
#!/data/data/com.termux/files/usr/bin/bash
exec "$RUNNER" "$BOX64" "$PRE/bin/ld.lld" "\$@"
EOF2

chmod +x "$SHADOW/bin/clang"
chmod +x "$SHADOW/bin/ld.lld"

echo "SHADOW_CLANG=YES"
echo "SHADOW_LLD=YES"

echo
echo "--- 3. PATCH TOOLCHAIN COPY ---"

TOOLCHAIN="$TEST/android.toolchain.cmake"

cp "$NDK/build/cmake/android.toolchain.cmake" "$TOOLCHAIN"

sed -i \
"s#\"\${CMAKE_ANDROID_NDK}/toolchains/llvm/prebuilt/\${ANDROID_HOST_TAG}\"#\"$TEST/prebuilt/linux-x86_64\"#" \
"$TOOLCHAIN"

echo "TOOLCHAIN_COPY=YES"

echo
echo "--- 4. SOURCE ---"

cat > "$SRC/main.c" <<'EOF2'
int main(void) {
    return 0;
}
EOF2

cat > "$SRC/CMakeLists.txt" <<EOF2
cmake_minimum_required(VERSION 3.22)
project(phase204 C)

add_executable(phase204 main.c)

target_link_options(phase204 PRIVATE
    -nostdlib
    -nostartfiles
    -Wl,-e,main
    -fuse-ld=$SHADOW/bin/ld.lld
)
EOF2

echo "SOURCE=YES"

echo
echo "--- 5. CMAKE CONFIGURE ---"

cmake \
  -S "$SRC" \
  -B "$BUILD" \
  -G Ninja \
  -DCMAKE_SYSTEM_NAME=Android \
  -DANDROID_PLATFORM=android-21 \
  -DANDROID_ABI=arm64-v8a \
  -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
  -DCMAKE_ANDROID_NDK="$NDK" \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
  2>&1 | tee "$TEST/configure.log"

CONFIGURE_RC=${PIPESTATUS[0]}

echo "CONFIGURE_RC=$CONFIGURE_RC"

echo
echo "--- 6. BUILD ---"

if [ "$CONFIGURE_RC" -eq 0 ]; then
    cmake --build "$BUILD" --verbose 2>&1 | tee "$TEST/build.log"
    BUILD_RC=${PIPESTATUS[0]}
else
    BUILD_RC=99
fi

echo "BUILD_RC=$BUILD_RC"

echo
echo "--- 7. EXECUTABLE ---"

if [ -f "$BUILD/phase204" ]; then
    echo "EXECUTABLE=CREATED"
    file "$BUILD/phase204"
else
    echo "EXECUTABLE=NOT_CREATED"
fi

echo
echo "--- 8. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "CONFIGURE_RC=$CONFIGURE_RC"
echo "BUILD_RC=$BUILD_RC"

if [ -f "$BUILD/phase204" ]; then
    echo "NDK_HOST_SHADOW=SUCCESS"
else
    echo "NDK_HOST_SHADOW=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 204 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TEST"
echo "RESULT_FILE=$ROOT/phase204_result.txt"
echo "=================================================="
