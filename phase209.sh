#!/data/data/com.termux/files/usr/bin/bash

set -u

echo "=================================================="
echo " PHASE 209: CMAKE LLD + LIBUNWIND PATH FIX"
echo "=================================================="

ROOT="$HOME/pocket_pcr_studio"
TEST="$ROOT/phase209_test"
SRC="$TEST/src"
BUILD="$TEST/build"

NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

CLANG="$PREFIX/bin/clang"
RUNNER="$PREFIX/bin/glibc-runner"
BOX64="$PREFIX/glibc/bin/box64"
LLD="$PRE/bin/ld.lld"

rm -rf "$TEST"
mkdir -p "$SRC" "$BUILD"

echo
echo "--- 1. TOOLS ---"
[ -x "$CLANG" ] && echo "NATIVE_CLANG=YES" || echo "NATIVE_CLANG=NO"
[ -f "$LLD" ] && echo "NDK_LLD=YES" || echo "NDK_LLD=NO"

echo
echo "--- 2. FIND LIBUNWIND ---"

UNWIND="$(find "$PRE" -name 'libunwind.a' -type f 2>/dev/null | head -1)"

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
echo "--- 3. CREATE LLD WRAPPER ---"

cat > "$TEST/ld-wrapper" <<EOF2
#!/data/data/com.termux/files/usr/bin/bash
exec "$RUNNER" "$BOX64" "$LLD" \
-L"$PRE/lib/clang/19/lib/linux/aarch64" \
-L"$PRE/lib/clang/19/lib/linux" \
-L"$PRE/sysroot/usr/lib/aarch64-linux-android/21" \
-L"$UNWIND_DIR" \
"\$@"
EOF2

chmod +x "$TEST/ld-wrapper"

echo "LD_WRAPPER=YES"

echo
echo "--- 4. SOURCE ---"

cat > "$SRC/main.c" <<'EOF2'
int main(void) {
    return 0;
}
EOF2

cat > "$SRC/CMakeLists.txt" <<EOF2
cmake_minimum_required(VERSION 3.22)
project(phase209 C)

add_executable(phase209 main.c)

target_link_options(phase209 PRIVATE
    -nostdlib
    -nostartfiles
    -Wl,-e,main
    -lunwind
)
EOF2

echo "SOURCE=YES"

echo
echo "--- 5. CMAKE CONFIGURE ---"

cmake \
    -S "$SRC" \
    -B "$BUILD" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="$CLANG" \
    -DCMAKE_C_COMPILER_TARGET=aarch64-linux-android21 \
    -DCMAKE_SYSROOT="$PRE/sysroot" \
    -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=$TEST/ld-wrapper" \
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

if [ -f "$BUILD/phase209" ]; then
    echo "EXECUTABLE=CREATED"
    file "$BUILD/phase209"
else
    echo "EXECUTABLE=NOT_CREATED"
fi

echo
echo "--- 8. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "CONFIGURE_RC=$CONFIGURE_RC"
echo "BUILD_RC=$BUILD_RC"

if [ -f "$BUILD/phase209" ]; then
    echo "CMAKE_LLD_LIBUNWIND=SUCCESS"
else
    echo "CMAKE_LLD_LIBUNWIND=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 209 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TEST"
echo "RESULT_FILE=$ROOT/phase209_result.txt"
echo "=================================================="
