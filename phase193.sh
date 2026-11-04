#!/data/data/com.termux/files/usr/bin/bash
set +e

echo "=================================================="
echo " PHASE 193: CMAKE + NDK LLD + LIBUNWIND INTEGRATION"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"
RUNNER="$PREFIX/bin/glibc-runner"
BOX64="$GLIBC/bin/box64"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

BIN="$X86/bin"
SYSROOT="$X86/sysroot"
RESOURCE="$X86/lib/clang/19"
RESLIB="$RESOURCE/lib/linux"

NATIVE_CLANG="$PREFIX/bin/clang"
LLD="$BIN/ld.lld"

AARCH64_LIB="$RESLIB/aarch64"

BUILTINS="$RESLIB/libclang_rt.builtins-aarch64-android.a"
UNWIND="$AARCH64_LIB/libunwind.a"

TESTDIR="$HOME/pocket_pcr_studio/phase193_test"
SRC="$TESTDIR/src"
BUILD="$TESTDIR/build"

rm -rf "$TESTDIR"
mkdir -p "$SRC" "$BUILD"

echo
echo "--- 1. TOOLCHAIN ---"
echo "HOST=$(uname -m)"
echo "NATIVE_CLANG=$NATIVE_CLANG"
echo "LLD=$LLD"
echo "SYSROOT=$SYSROOT"
echo "AARCH64_LIB=$AARCH64_LIB"
echo "UNWIND=$UNWIND"

echo
echo "--- 2. VERIFY LIBUNWIND ---"

if [ -f "$UNWIND" ]; then
    echo "LIBUNWIND_EXISTS=YES"
    file "$UNWIND"
else
    echo "LIBUNWIND_EXISTS=NO"
fi

echo
echo "--- 3. CREATE LLD WRAPPER ---"

cat > "$TESTDIR/ld-wrapper" <<WRAP
#!/data/data/com.termux/files/usr/bin/bash

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
RUNNER="\$PREFIX/bin/glibc-runner"
BOX64="\$PREFIX/glibc/bin/box64"

exec "\$RUNNER" "\$BOX64" "$LLD" "\$@"
WRAP

chmod +x "$TESTDIR/ld-wrapper"

echo "WRAPPER=$TESTDIR/ld-wrapper"

"$TESTDIR/ld-wrapper" --version 2>&1
WRAPPER_RC=$?

echo "WRAPPER_RC=$WRAPPER_RC"

echo
echo "--- 4. CREATE CMAKE PROJECT ---"

cat > "$SRC/main.c" <<'SRC'
#include <stdio.h>

int main(void)
{
    return 0;
}
SRC

cat > "$SRC/CMakeLists.txt" <<CMAKE
cmake_minimum_required(VERSION 3.20)

project(phase193 C)

set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION 21)
set(CMAKE_ANDROID_ARCH_ABI arm64-v8a)

set(CMAKE_C_COMPILER "$NATIVE_CLANG")

set(CMAKE_C_FLAGS
    "--target=aarch64-linux-android21 --sysroot=$SYSROOT"
)

set(CMAKE_EXE_LINKER_FLAGS
    "-fuse-ld=$TESTDIR/ld-wrapper"
    "-L$AARCH64_LIB"
    "-L$RESLIB"
    "-L$SYSROOT/usr/lib/aarch64-linux-android/21"
    "-lunwind"
)

add_executable(phase193 main.c)
CMAKE

echo "CMAKE_PROJECT_CREATED=YES"

echo
echo "--- 5. CMAKE CONFIGURE ---"

cmake \
    -S "$SRC" \
    -B "$BUILD" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="$NATIVE_CLANG" \
    2>&1 | tee "$TESTDIR/configure.log"

CONFIGURE_RC=${PIPESTATUS[0]}

echo "CONFIGURE_RC=$CONFIGURE_RC"

echo
echo "--- 6. CMAKE CACHE ---"

if [ -f "$BUILD/CMakeCache.txt" ]; then
    grep -E \
        'CMAKE_C_COMPILER:|CMAKE_C_FLAGS:|CMAKE_EXE_LINKER_FLAGS:' \
        "$BUILD/CMakeCache.txt" 2>/dev/null
fi

echo
echo "--- 7. CMAKE BUILD ---"

cmake --build "$BUILD" --verbose 2>&1 | tee "$TESTDIR/build.log"

BUILD_RC=${PIPESTATUS[0]}

echo "BUILD_RC=$BUILD_RC"

echo
echo "--- 8. EXECUTABLE ---"

if [ -f "$BUILD/phase193" ]; then
    echo "EXECUTABLE=CREATED"
    file "$BUILD/phase193"

    echo
    echo "--- ELF CHECK ---"
    readelf -h "$BUILD/phase193" 2>/dev/null | \
        grep -E 'Class:|Machine:|Type:|Entry point' || true

    echo
    echo "--- NEEDED LIBRARIES ---"
    readelf -d "$BUILD/phase193" 2>/dev/null | \
        grep NEEDED || true
else
    echo "EXECUTABLE=NOT_CREATED"
fi

echo
echo "--- 9. LINK COMMAND ---"

if [ -f "$BUILD/CMakeFiles/phase193.dir/link.txt" ]; then
    cat "$BUILD/CMakeFiles/phase193.dir/link.txt"
else
    echo "LINK_TXT=NOT_FOUND"
fi

echo
echo "--- 10. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "WRAPPER_RC=$WRAPPER_RC"
echo "CONFIGURE_RC=$CONFIGURE_RC"
echo "BUILD_RC=$BUILD_RC"

if [ -f "$BUILD/phase193" ]; then
    echo "CMAKE_EXECUTABLE=SUCCESS"
else
    echo "CMAKE_EXECUTABLE=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 193 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TESTDIR"
echo "RESULT_FILE=$HOME/pocket_pcr_studio/phase193_result.txt"
echo "=================================================="
