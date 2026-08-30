#!/data/data/com.termux/files/usr/bin/bash

set +e

echo "=================================================="
echo " PHASE 213: CMAKE FORCE LIBUNWIND SEARCH PATH"
echo "=================================================="

ROOT="$HOME/pocket_pcr_studio"
TEST="$ROOT/phase213_test"

CMAKE="$PREFIX/bin/cmake"
NINJA="$PREFIX/bin/ninja"
CLANG="$PREFIX/bin/clang"
CLANGXX="$PREFIX/bin/clang++"

NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

SYSROOT="$PRE/sysroot"

echo
echo "--- 1. TOOLS ---"

[ -x "$CMAKE" ] && echo "CMAKE=YES" || echo "CMAKE=NO"
[ -x "$NINJA" ] && echo "NINJA=YES" || echo "NINJA=NO"
[ -x "$CLANG" ] && echo "CLANG=YES" || echo "CLANG=NO"
[ -x "$CLANGXX" ] && echo "CLANGXX=YES" || echo "CLANGXX=NO"

echo
echo "--- 2. FIND LIBUNWIND ---"

UNWIND="$(find "$PRE/lib" -name libunwind.a -type f 2>/dev/null | head -1)"

if [ -n "$UNWIND" ]; then
    echo "LIBUNWIND=YES"
    echo "UNWIND=$UNWIND"
    UNWIND_DIR="$(dirname "$UNWIND")"
    echo "UNWIND_DIR=$UNWIND_DIR"
else
    echo "LIBUNWIND=NO"
    UNWIND_DIR=""
fi

echo
echo "--- 3. CLEAN TEST ---"

rm -rf "$TEST"

mkdir -p "$TEST/src"
mkdir -p "$TEST/build"

cat > "$TEST/src/main.c" <<'EOF'
#include <stdio.h>

int main(void)
{
    return 0;
}
EOF

cat > "$TEST/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.18)

project(phase213 C)

add_executable(phase213 src/main.c)
EOF

echo "SOURCE=YES"

echo
echo "--- 4. CMAKE CONFIGURE ---"

if [ -z "$UNWIND_DIR" ]; then
    echo "ERROR: libunwind.a not found"
    CONFIGURE_RC=1
else

    "$CMAKE" \
        -S "$TEST" \
        -B "$TEST/build" \
        -G Ninja \
        -DCMAKE_SYSTEM_NAME=Android \
        -DCMAKE_SYSTEM_VERSION=21 \
        -DANDROID_PLATFORM=android-21 \
        -DANDROID_ABI=arm64-v8a \
        -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
        -DANDROID_NDK="$NDK" \
        -DCMAKE_ANDROID_NDK="$NDK" \
        -DCMAKE_C_COMPILER="$CLANG" \
        -DCMAKE_CXX_COMPILER="$CLANGXX" \
        -DCMAKE_C_COMPILER_TARGET=aarch64-linux-android21 \
        -DCMAKE_CXX_COMPILER_TARGET=aarch64-linux-android21 \
        -DCMAKE_C_FLAGS="--target=aarch64-linux-android21 --sysroot=$SYSROOT" \
        -DCMAKE_CXX_FLAGS="--target=aarch64-linux-android21 --sysroot=$SYSROOT" \
        -DCMAKE_EXE_LINKER_FLAGS="-L$UNWIND_DIR" \
        -DCMAKE_SHARED_LINKER_FLAGS="-L$UNWIND_DIR" \
        -DCMAKE_MODULE_LINKER_FLAGS="-L$UNWIND_DIR" \
        2>&1 | tee "$TEST/configure.log"

    CONFIGURE_RC=${PIPESTATUS[0]}
fi

echo "CONFIGURE_RC=$CONFIGURE_RC"

echo
echo "--- 5. CACHE LINKER FLAGS ---"

CACHE="$TEST/build/CMakeCache.txt"

if [ -f "$CACHE" ]; then
    echo "CACHE=YES"

    echo
    echo "CMAKE_EXE_LINKER_FLAGS:"
    grep '^CMAKE_EXE_LINKER_FLAGS:' "$CACHE" || true

    echo
    echo "CMAKE_SHARED_LINKER_FLAGS:"
    grep '^CMAKE_SHARED_LINKER_FLAGS:' "$CACHE" || true

    echo
    echo "CMAKE_MODULE_LINKER_FLAGS:"
    grep '^CMAKE_MODULE_LINKER_FLAGS:' "$CACHE" || true
else
    echo "CACHE=NO"
fi

echo
echo "--- 6. BUILD ---"

if [ "$CONFIGURE_RC" -eq 0 ]; then

    "$CMAKE" \
        --build "$TEST/build" \
        --verbose \
        2>&1 | tee "$TEST/build.log"

    BUILD_RC=${PIPESTATUS[0]}

else
    BUILD_RC=99
fi

echo "BUILD_RC=$BUILD_RC"

echo
echo "--- 7. EXECUTABLE ---"

if [ -f "$TEST/build/phase213" ]; then
    echo "EXECUTABLE=CREATED"
    file "$TEST/build/phase213"
else
    echo "EXECUTABLE=NOT_CREATED"
fi

echo
echo "--- 8. LINK COMMAND ---"

if [ -f "$TEST/build/build.ninja" ]; then
    grep -n "libunwind\|-L" "$TEST/build/build.ninja" | head -30 || true
fi

echo
echo "--- 9. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "CONFIGURE_RC=$CONFIGURE_RC"
echo "BUILD_RC=$BUILD_RC"

if [ -f "$TEST/build/phase213" ]; then
    echo "CMAKE_FORCE_LIBUNWIND=SUCCESS"
else
    echo "CMAKE_FORCE_LIBUNWIND=FAILED"
fi

echo "=================================================="
echo " PHASE 213 COMPLETE"
echo "=================================================="

echo "TESTDIR=$TEST"
echo "CONFIGURE_LOG=$TEST/configure.log"
echo "BUILD_LOG=$TEST/build.log"

echo "=================================================="
