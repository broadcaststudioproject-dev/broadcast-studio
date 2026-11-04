#!/data/data/com.termux/files/usr/bin/bash

set +e

ROOT="$HOME/pocket_pcr_studio"
TEST="$ROOT/phase205_test"
SRC="$TEST/src"
BUILD="$TEST/build"

NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
RUNNER="$PREFIX/bin/glibc-runner"
BOX64="$PREFIX/glibc/bin/box64"

rm -rf "$TEST"
mkdir -p "$SRC" "$BUILD"

echo "=================================================="
echo " PHASE 205: NDK TOOLCHAIN RELATIVE INCLUDE FIX"
echo "=================================================="

echo
echo "--- 1. VERIFY NDK ---"

[ -f "$PRE/bin/clang" ] && echo "CLANG=YES" || echo "CLANG=NO"
[ -f "$PRE/bin/ld.lld" ] && echo "LLD=YES" || echo "LLD=NO"
[ -f "$NDK/build/cmake/android.toolchain.cmake" ] && echo "TOOLCHAIN=YES" || echo "TOOLCHAIN=NO"
[ -f "$NDK/build/cmake/android-legacy.toolchain.cmake" ] && echo "LEGACY=YES" || echo "LEGACY=NO"

echo
echo "--- 2. COPY TOOLCHAIN FILES ---"

cp "$NDK/build/cmake/android.toolchain.cmake" "$TEST/"
cp "$NDK/build/cmake/android-legacy.toolchain.cmake" "$TEST/"

echo "TOOLCHAIN_COPY=YES"

echo
echo "--- 3. CREATE SHADOW HOST ---"

SHADOW="$TEST/prebuilt/linux-x86_64"

mkdir -p "$SHADOW/bin"

ln -s "$PRE/sysroot" "$SHADOW/sysroot"
ln -s "$PRE/lib" "$SHADOW/lib"

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

echo "SHADOW=YES"

echo
echo "--- 4. PATCH HOST ROOT ---"

sed -i \
"s#\${CMAKE_ANDROID_NDK}/toolchains/llvm/prebuilt/\${ANDROID_HOST_TAG}#$TEST/prebuilt/linux-x86_64#g" \
"$TEST/android-legacy.toolchain.cmake"

echo "LEGACY_PATCH=YES"

echo
echo "--- 5. SOURCE ---"

cat > "$SRC/main.c" <<'EOF2'
int main(void)
{
    return 0;
}
EOF2

cat > "$SRC/CMakeLists.txt" <<EOF2
cmake_minimum_required(VERSION 3.22)

project(phase205 C)

add_executable(phase205 main.c)

target_link_options(phase205 PRIVATE
    -nostdlib
    -nostartfiles
    -Wl,-e,main
    -fuse-ld=$SHADOW/bin/ld.lld
)
EOF2

echo "SOURCE=YES"

echo
echo "--- 6. CONFIGURE ---"

cmake \
  -S "$SRC" \
  -B "$BUILD" \
  -G Ninja \
  -DCMAKE_SYSTEM_NAME=Android \
  -DANDROID_PLATFORM=android-21 \
  -DANDROID_ABI=arm64-v8a \
  -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
  -DCMAKE_ANDROID_NDK="$NDK" \
  -DCMAKE_TOOLCHAIN_FILE="$TEST/android.toolchain.cmake" \
  2>&1 | tee "$TEST/configure.log"

CONFIGURE_RC=${PIPESTATUS[0]}

echo "CONFIGURE_RC=$CONFIGURE_RC"

echo
echo "--- 7. BUILD ---"

if [ "$CONFIGURE_RC" -eq 0 ]; then
    cmake --build "$BUILD" --verbose \
      2>&1 | tee "$TEST/build.log"

    BUILD_RC=${PIPESTATUS[0]}
else
    BUILD_RC=99
fi

echo "BUILD_RC=$BUILD_RC"

echo
echo "--- 8. EXECUTABLE ---"

if [ -f "$BUILD/phase205" ]; then
    echo "EXECUTABLE=CREATED"
    file "$BUILD/phase205"
else
    echo "EXECUTABLE=NOT_CREATED"
fi

echo
echo "--- 9. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "CONFIGURE_RC=$CONFIGURE_RC"
echo "BUILD_RC=$BUILD_RC"

if [ -f "$BUILD/phase205" ]; then
    echo "NDK_HOST_SHADOW=SUCCESS"
else
    echo "NDK_HOST_SHADOW=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 205 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TEST"
echo "RESULT_FILE=$ROOT/phase205_result.txt"
echo "=================================================="
