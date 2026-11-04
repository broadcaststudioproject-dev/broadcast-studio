#!/data/data/com.termux/files/usr/bin/bash
set +e

echo "=================================================="
echo " PHASE 190: NATIVE CLANG + NDK LLD CMAKE TOOLCHAIN"
echo "=================================================="

PROJECT="$HOME/pocket_pcr_studio"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

NATIVE_CLANG="$PREFIX/bin/clang"
NATIVE_CLANGXX="$PREFIX/bin/clang++"
LLD="$X86/bin/ld.lld"
SYSROOT="$X86/sysroot"

TESTDIR="$PROJECT/phase190_test"
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"

echo
echo "--- 1. ENVIRONMENT ---"
echo "HOST=$(uname -m)"
echo "NATIVE_CLANG=$NATIVE_CLANG"
echo "NATIVE_CLANGXX=$NATIVE_CLANGXX"
echo "NDK=$NDK"
echo "LLD=$LLD"
echo "SYSROOT=$SYSROOT"

echo
echo "--- 2. VERIFY NATIVE CLANG ---"
"$NATIVE_CLANG" --version
echo "CLANG_RC=$?"

echo
echo "--- 3. CREATE LLD WRAPPER ---"

cat > "$TESTDIR/ld-wrapper" <<WRAP
#!/data/data/com.termux/files/usr/bin/bash
exec "$PREFIX/bin/glibc-runner" "$PREFIX/glibc/bin/box64" "$LLD" "\$@"
WRAP

chmod +x "$TESTDIR/ld-wrapper"

echo "WRAPPER=$TESTDIR/ld-wrapper"

"$TESTDIR/ld-wrapper" --version 2>&1
echo "WRAPPER_RC=$?"

echo
echo "--- 4. CREATE CMAKE TOOLCHAIN ---"

cat > "$TESTDIR/android-native-toolchain.cmake" <<CMAKE
set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION 21)

set(CMAKE_ANDROID_NDK "$NDK")
set(CMAKE_ANDROID_ARCH_ABI arm64-v8a)
set(CMAKE_ANDROID_API 21)

set(CMAKE_C_COMPILER "$NATIVE_CLANG")
set(CMAKE_CXX_COMPILER "$NATIVE_CLANGXX")

set(CMAKE_C_COMPILER_TARGET aarch64-linux-android21)
set(CMAKE_CXX_COMPILER_TARGET aarch64-linux-android21)

set(CMAKE_SYSROOT "$SYSROOT")

set(CMAKE_LINKER "$TESTDIR/ld-wrapper")

set(CMAKE_EXE_LINKER_FLAGS
    "-fuse-ld=$TESTDIR/ld-wrapper"
    CACHE STRING "" FORCE)

set(CMAKE_SHARED_LINKER_FLAGS
    "-fuse-ld=$TESTDIR/ld-wrapper"
    CACHE STRING "" FORCE)

set(CMAKE_MODULE_LINKER_FLAGS
    "-fuse-ld=$TESTDIR/ld-wrapper"
    CACHE STRING "" FORCE)

set(CMAKE_C_FLAGS
    "--target=aarch64-linux-android21"
    CACHE STRING "" FORCE)

set(CMAKE_CXX_FLAGS
    "--target=aarch64-linux-android21"
    CACHE STRING "" FORCE)

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
CMAKE

echo "TOOLCHAIN_CREATED=YES"
cat "$TESTDIR/android-native-toolchain.cmake"

echo
echo "--- 5. CREATE CMAKE TEST PROJECT ---"

mkdir -p "$TESTDIR/src"

cat > "$TESTDIR/src/main.c" <<'SRC'
#include <stdio.h>

int main(void)
{
    return 0;
}
SRC

cat > "$TESTDIR/src/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.18)

project(Phase190 C)

add_executable(phase190 main.c)
CMAKE

echo
echo "--- 6. CMAKE VERSION ---"
cmake --version
CMAKE_RC=$?

echo "CMAKE_RC=$CMAKE_RC"

echo
echo "--- 7. CONFIGURE ---"

cmake \
    -S "$TESTDIR/src" \
    -B "$TESTDIR/build" \
    -DCMAKE_TOOLCHAIN_FILE="$TESTDIR/android-native-toolchain.cmake" \
    -DCMAKE_BUILD_TYPE=Release \
    2>&1 | tee "$TESTDIR/cmake_configure.log"

CONFIGURE_RC=${PIPESTATUS[0]}

echo
echo "CONFIGURE_RC=$CONFIGURE_RC"

echo
echo "--- 8. BUILD ---"

if [ "$CONFIGURE_RC" -eq 0 ]; then
    cmake \
        --build "$TESTDIR/build" \
        --verbose \
        2>&1 | tee "$TESTDIR/cmake_build.log"

    BUILD_RC=${PIPESTATUS[0]}
else
    BUILD_RC=99
fi

echo
echo "BUILD_RC=$BUILD_RC"

echo
echo "--- 9. OUTPUT ---"

if [ -f "$TESTDIR/build/phase190" ]; then
    echo "EXECUTABLE=CREATED"
    file "$TESTDIR/build/phase190"
    readelf -h "$TESTDIR/build/phase190" 2>/dev/null | grep -E 'Class|Machine|Type'
else
    echo "EXECUTABLE=NOT_CREATED"
fi

echo
echo "--- 10. CMAKE CACHE COMPILERS ---"

CACHE="$TESTDIR/build/CMakeCache.txt"

if [ -f "$CACHE" ]; then
    grep -E \
        'CMAKE_(C|CXX)_COMPILER:|CMAKE_(C|CXX)_COMPILER_TARGET:|CMAKE_LINKER:' \
        "$CACHE" 2>/dev/null
fi

echo
echo "--- 11. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "CONFIGURE_RC=$CONFIGURE_RC"
echo "BUILD_RC=$BUILD_RC"

if [ -f "$TESTDIR/build/phase190" ]; then
    echo "CMAKE_NATIVE_CLANG_NDK_LLD=SUCCESS"
else
    echo "CMAKE_NATIVE_CLANG_NDK_LLD=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 190 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TESTDIR"
echo "RESULT_FILE=$PROJECT/phase190_result.txt"
echo "=================================================="
