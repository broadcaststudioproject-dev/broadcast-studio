
#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 212: CMAKE ABSOLUTE LIBUNWIND LINK FIX"
echo "=================================================="

ROOT="$HOME/pocket_pcr_studio"
TEST="$ROOT/phase212_test"
SRC="$TEST/src"
BUILD="$TEST/build"

NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

CMAKE="$PREFIX/opt/android-sdk/cmake/3.22.1/bin/cmake"
NINJA="$PREFIX/opt/android-sdk/cmake/3.22.1/bin/ninja"
CLANG="$PREFIX/bin/clang"

UNWIND="$PRE/lib/i386-unknown-linux-gnu/libunwind.a"

rm -rf "$TEST"
mkdir -p "$SRC" "$BUILD"

echo
echo "--- 1. VERIFY TOOLS ---"

[ -x "$CLANG" ] && echo "NATIVE_CLANG=YES" || echo "NATIVE_CLANG=NO"
[ -x "$CMAKE" ] && echo "CMAKE=YES" || echo "CMAKE=NO"
[ -x "$NINJA" ] && echo "NINJA=YES" || echo "NINJA=NO"

echo
echo "--- 2. VERIFY NDK ---"

[ -f "$PRE/sysroot/usr/include/stdint.h" ] \
    && echo "SYSROOT=YES" \
    || echo "SYSROOT=NO"

[ -f "$PRE/bin/ld.lld" ] \
    && echo "LLD=YES" \
    || echo "LLD=NO"

echo
echo "--- 3. FIND LIBUNWIND ---"

if [ -f "$UNWIND" ]; then
    echo "LIBUNWIND=YES"
    echo "UNWIND=$UNWIND"
    ls -lh "$UNWIND"
else
    echo "LIBUNWIND=NO"
    echo "EXPECTED=$UNWIND"
fi

echo
echo "--- 4. SOURCE ---"

cat > "$SRC/main.c" <<'EOF'
#include <stdint.h>

int main(void)
{
    volatile int value = 212;

    if (value == 212)
        return 0;

    return 1;
}
EOF

cat > "$SRC/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.22)

project(flutter_jni_phase212 C)

message(STATUS "======================================")
message(STATUS " PHASE 212 CMAKE CONFIGURATION")
message(STATUS "======================================")

message(STATUS "CMAKE_VERSION=\${CMAKE_VERSION}")
message(STATUS "CMAKE_HOST_SYSTEM_NAME=\${CMAKE_HOST_SYSTEM_NAME}")
message(STATUS "CMAKE_HOST_SYSTEM_PROCESSOR=\${CMAKE_HOST_SYSTEM_PROCESSOR}")

message(STATUS "CMAKE_SYSTEM_NAME=\${CMAKE_SYSTEM_NAME}")
message(STATUS "CMAKE_SYSTEM_PROCESSOR=\${CMAKE_SYSTEM_PROCESSOR}")

message(STATUS "ANDROID_ABI=\${ANDROID_ABI}")
message(STATUS "ANDROID_PLATFORM=\${ANDROID_PLATFORM}")

message(STATUS "ANDROID_NDK=\${ANDROID_NDK}")
message(STATUS "CMAKE_ANDROID_NDK=\${CMAKE_ANDROID_NDK}")

message(STATUS "CMAKE_C_COMPILER=\${CMAKE_C_COMPILER}")
message(STATUS "CMAKE_C_COMPILER_ID=\${CMAKE_C_COMPILER_ID}")
message(STATUS "CMAKE_C_COMPILER_TARGET=\${CMAKE_C_COMPILER_TARGET}")

message(STATUS "LIBUNWIND=$UNWIND")

add_executable(flutter_jni_phase212 main.c)

target_compile_options(
    flutter_jni_phase212
    PRIVATE
    -O2
    -fdata-sections
    -ffunction-sections
)

target_link_options(
    flutter_jni_phase212
    PRIVATE
    -nostdlib
    -nostartfiles
    -Wl,-e,main
)

# IMPORTANT:
# Use absolute libunwind archive path.
# Do NOT use -lunwind here.

target_link_libraries(
    flutter_jni_phase212
    PRIVATE
    "$UNWIND"
)

EOF

echo "SOURCE=YES"

echo
echo "--- 5. CONFIGURE ---"

"$CMAKE" \
    -S "$SRC" \
    -B "$BUILD" \
    -G Ninja \
    -DCMAKE_SYSTEM_NAME=Android \
    -DCMAKE_SYSTEM_VERSION=21 \
    -DANDROID_PLATFORM=android-21 \
    -DANDROID_ABI=arm64-v8a \
    -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
    -DANDROID_NDK="$NDK" \
    -DCMAKE_ANDROID_NDK="$NDK" \
    -DCMAKE_C_COMPILER="$CLANG" \
    -DCMAKE_C_COMPILER_TARGET=aarch64-linux-android21 \
    -DCMAKE_C_FLAGS="--sysroot=$PRE/sysroot" \
    2>&1 | tee "$TEST/configure.log"

CONFIGURE_RC=${PIPESTATUS[0]}

echo
echo "CONFIGURE_RC=$CONFIGURE_RC"

echo
echo "--- 6. CACHE ---"

CACHE="$BUILD/CMakeCache.txt"

if [ -f "$CACHE" ]; then

    echo "CACHE=YES"

    echo
    grep '^CMAKE_C_COMPILER:' "$CACHE" || true
    grep '^CMAKE_C_COMPILER_TARGET:' "$CACHE" || true
    grep '^ANDROID_NDK:' "$CACHE" || true
    grep '^CMAKE_ANDROID_NDK:' "$CACHE" || true

else

    echo "CACHE=NO"

fi

echo
echo "--- 7. BUILD ---"

if [ "$CONFIGURE_RC" -eq 0 ]; then

    "$CMAKE" \
        --build "$BUILD" \
        --verbose \
        2>&1 | tee "$TEST/build.log"

    BUILD_RC=${PIPESTATUS[0]}

else

    BUILD_RC=99

fi

echo
echo "BUILD_RC=$BUILD_RC"

echo
echo "--- 8. EXECUTABLE ---"

if [ -f "$BUILD/flutter_jni_phase212" ]; then

    echo "EXECUTABLE=CREATED"

    file "$BUILD/flutter_jni_phase212"

    echo
    echo "--- ELF HEADER ---"

    readelf -h "$BUILD/flutter_jni_phase212" 2>/dev/null \
        | grep -E 'Class:|Type:|Machine:' || true

else

    echo "EXECUTABLE=NOT_CREATED"

fi

echo
echo "--- 9. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "CONFIGURE_RC=$CONFIGURE_RC"
echo "BUILD_RC=$BUILD_RC"

if [ -f "$BUILD/flutter_jni_phase212" ]; then

    echo "CMAKE_ABSOLUTE_LIBUNWIND=SUCCESS"

else

    echo "CMAKE_ABSOLUTE_LIBUNWIND=FAILED"

fi

echo
echo "=================================================="
echo " PHASE 212 COMPLETE"
echo "=================================================="

echo "TESTDIR=$TEST"
echo "CONFIGURE_LOG=$TEST/configure.log"
echo "BUILD_LOG=$TEST/build.log"

echo "=================================================="
