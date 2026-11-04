#!/data/data/com.termux/files/usr/bin/bash
set +e

echo "=================================================="
echo " PHASE 194: SMALL CMAKE LIBUNWIND TEST"
echo "=================================================="

P=/data/data/com.termux/files/usr
NDK=$P/opt/android-sdk/ndk/28.2.13676358
X=$NDK/toolchains/llvm/prebuilt/linux-x86_64
CLANG=$P/bin/clang
LLD=$X/bin/ld.lld
SYSROOT=$X/sysroot
ULIB=$X/lib/clang/19/lib/linux/aarch64

T=$HOME/pocket_pcr_studio/phase194_test
rm -rf "$T"
mkdir -p "$T/src" "$T/build"

echo
echo "--- 1. CREATE WRAPPER ---"

cat > "$T/ld-wrapper" <<WRAP
#!/data/data/com.termux/files/usr/bin/bash
exec "$P/bin/glibc-runner" "$P/glibc/bin/box64" "$LLD" \
-L"$ULIB" \
-L"$X/lib/clang/19/lib/linux" \
-L"$SYSROOT/usr/lib/aarch64-linux-android/21" \
"\$@"
WRAP

chmod +x "$T/ld-wrapper"

"$T/ld-wrapper" --version 2>&1
echo "WRAPPER_RC=$?"

echo
echo "--- 2. CREATE CMAKE PROJECT ---"

cat > "$T/src/main.c" <<'SRC'
int main(void)
{
    return 0;
}
SRC

cat > "$T/src/CMakeLists.txt" <<CMAKE
cmake_minimum_required(VERSION 3.20)
project(phase194 C)

set(CMAKE_C_COMPILER "$CLANG")
set(CMAKE_C_FLAGS "--target=aarch64-linux-android21 --sysroot=$SYSROOT")
set(CMAKE_EXE_LINKER_FLAGS "-fuse-ld=$T/ld-wrapper")

add_executable(phase194 main.c)
target_link_options(phase194 PRIVATE "-lunwind")
CMAKE

echo "PROJECT=CREATED"

echo
echo "--- 3. CONFIGURE ---"

cmake -S "$T/src" -B "$T/build" \
-DCMAKE_BUILD_TYPE=Release \
2>&1 | tee "$T/configure.log"

CONFIGURE_RC=${PIPESTATUS[0]}
echo "CONFIGURE_RC=$CONFIGURE_RC"

echo
echo "--- 4. BUILD ---"

cmake --build "$T/build" --verbose \
2>&1 | tee "$T/build.log"

BUILD_RC=${PIPESTATUS[0]}
echo "BUILD_RC=$BUILD_RC"

echo
echo "--- 5. RESULT ---"

if [ -f "$T/build/phase194" ]; then
    echo "EXECUTABLE=CREATED"
    file "$T/build/phase194"
else
    echo "EXECUTABLE=NOT_CREATED"
fi

echo
echo "--- 6. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "CONFIGURE_RC=$CONFIGURE_RC"
echo "BUILD_RC=$BUILD_RC"

if [ -f "$T/build/phase194" ]; then
    echo "CMAKE_EXECUTABLE=SUCCESS"
else
    echo "CMAKE_EXECUTABLE=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 194 COMPLETE"
echo "=================================================="
echo "TESTDIR=$T"
echo "RESULT_FILE=$HOME/pocket_pcr_studio/phase194_result.txt"
echo "=================================================="
