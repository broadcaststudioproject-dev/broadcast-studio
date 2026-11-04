#!/data/data/com.termux/files/usr/bin/bash
set +e

echo "=================================================="
echo " PHASE 191: FIX LLD SEARCH PATH FOR ARM64 LIBUNWIND"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"
RUNNER="$PREFIX/bin/glibc-runner"
BOX64="$GLIBC/bin/box64"

NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

CLANG="$PREFIX/bin/clang"
LLD="$X86/bin/ld.lld"

SYSROOT="$X86/sysroot"
RESOURCE="$X86/lib/clang/19"
RESLIB="$RESOURCE/lib/linux"
ARM64LIB="$RESLIB/aarch64"

LIBDIR="$SYSROOT/usr/lib/aarch64-linux-android/21"

BUILTINS="$RESLIB/libclang_rt.builtins-aarch64-android.a"
UNWIND="$ARM64LIB/libunwind.a"
CRTBEGIN="$LIBDIR/crtbegin_dynamic.o"
CRTEND="$LIBDIR/crtend_android.o"
LIBC="$LIBDIR/libc.so"
LIBDL="$LIBDIR/libdl.so"

TESTDIR="$HOME/pocket_pcr_studio/phase191_test"

rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"

echo
echo "--- 1. TOOLCHAIN ---"
echo "HOST=$(uname -m)"
echo "CLANG=$CLANG"
echo "LLD=$LLD"
echo "SYSROOT=$SYSROOT"
echo "ARM64LIB=$ARM64LIB"
echo "UNWIND=$UNWIND"

echo
echo "--- 2. VERIFY LIBUNWIND ---"

if [ -f "$UNWIND" ]; then
    echo "UNWIND_EXISTS=YES"
    file "$UNWIND"
else
    echo "UNWIND_EXISTS=NO"
fi

echo
echo "--- 3. CREATE CORRECTED WRAPPER ---"

cat > "$TESTDIR/ld-wrapper" <<WRAP
#!/data/data/com.termux/files/usr/bin/bash

PREFIX="$PREFIX"
RUNNER="$RUNNER"
BOX64="$BOX64"
LLD="$LLD"

RESOURCE="$RESOURCE"
RESLIB="$RESLIB"
ARM64LIB="$ARM64LIB"
SYSROOT="$SYSROOT"
LIBDIR="$LIBDIR"

exec "\$RUNNER" "\$BOX64" "\$LLD" \
    -L"\$ARM64LIB" \
    -L"\$RESLIB" \
    -L"\$LIBDIR" \
    -L"\$SYSROOT/usr/lib/aarch64-linux-android" \
    "\$@"
WRAP

chmod +x "$TESTDIR/ld-wrapper"

echo "WRAPPER=$TESTDIR/ld-wrapper"
cat "$TESTDIR/ld-wrapper"

echo
echo "--- 4. TEST LLD THROUGH WRAPPER ---"

"$TESTDIR/ld-wrapper" --version 2>&1
WRAPPER_RC=$?

echo "WRAPPER_RC=$WRAPPER_RC"

echo
echo "--- 5. CREATE SOURCE ---"

cat > "$TESTDIR/main.c" <<'SRC'
int main(void)
{
    return 0;
}
SRC

echo
echo "--- 6. NATIVE CLANG COMPILE ---"

"$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -O3 \
    -DNDEBUG \
    -c "$TESTDIR/main.c" \
    -o "$TESTDIR/main.o" \
    2>&1

COMPILE_RC=$?

echo "COMPILE_RC=$COMPILE_RC"

if [ -f "$TESTDIR/main.o" ]; then
    echo "OBJECT=YES"
    file "$TESTDIR/main.o"
else
    echo "OBJECT=NO"
fi

echo
echo "--- 7. DIRECT WRAPPER LINK WITH LIBUNWIND ---"

"$TESTDIR/ld-wrapper" \
    --sysroot="$SYSROOT" \
    -EL \
    -z now \
    -z relro \
    -z max-page-size=16384 \
    -m aarch64linux \
    -pie \
    -dynamic-linker /system/bin/linker64 \
    -o "$TESTDIR/direct_link" \
    "$CRTBEGIN" \
    "$TESTDIR/main.o" \
    "$BUILTINS" \
    -l:libunwind.a \
    -ldl \
    -lc \
    "$CRTEND" \
    2>&1

DIRECT_RC=$?

echo "DIRECT_RC=$DIRECT_RC"

if [ -f "$TESTDIR/direct_link" ]; then
    echo "DIRECT_LINK=CREATED"
    file "$TESTDIR/direct_link"
else
    echo "DIRECT_LINK=NOT_CREATED"
fi

echo
echo "--- 8. NATIVE CLANG + CORRECTED WRAPPER ---"

"$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -O3 \
    -DNDEBUG \
    -fuse-ld="$TESTDIR/ld-wrapper" \
    "$TESTDIR/main.o" \
    -o "$TESTDIR/native_link" \
    2>&1

NATIVE_LINK_RC=$?

echo "NATIVE_LINK_RC=$NATIVE_LINK_RC"

if [ -f "$TESTDIR/native_link" ]; then
    echo "NATIVE_LINK=CREATED"
    file "$TESTDIR/native_link"
else
    echo "NATIVE_LINK=NOT_CREATED"
fi

echo
echo "--- 9. CMAKE TEST PROJECT ---"

mkdir -p "$TESTDIR/src" "$TESTDIR/build"

cat > "$TESTDIR/src/main.c" <<'SRC'
int main(void)
{
    return 0;
}
SRC

cat > "$TESTDIR/src/CMakeLists.txt" <<CMAKE
cmake_minimum_required(VERSION 3.20)

project(phase191 C)

add_executable(phase191 main.c)

target_compile_options(phase191 PRIVATE
    -O3
    -DNDEBUG
)

set_target_properties(phase191 PROPERTIES
    LINK_FLAGS "-fuse-ld=$TESTDIR/ld-wrapper"
)
CMAKE

echo
echo "--- 10. CMAKE CONFIGURE ---"

cmake \
    -S "$TESTDIR/src" \
    -B "$TESTDIR/build" \
    -DCMAKE_C_COMPILER="$CLANG" \
    -DCMAKE_SYSTEM_NAME=Android \
    -DCMAKE_SYSTEM_VERSION=21 \
    -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
    2>&1 | tee "$TESTDIR/cmake_configure.log"

CONFIGURE_RC=${PIPESTATUS[0]}

echo "CONFIGURE_RC=$CONFIGURE_RC"

echo
echo "--- 11. CMAKE BUILD ---"

cmake \
    --build "$TESTDIR/build" \
    --verbose \
    2>&1 | tee "$TESTDIR/cmake_build.log"

BUILD_RC=${PIPESTATUS[0]}

echo "BUILD_RC=$BUILD_RC"

echo
echo "--- 12. SEARCH OUTPUT ---"

find "$TESTDIR" -maxdepth 4 -type f \
    \( -name "phase191" -o -name "native_link" -o -name "direct_link" \) \
    -print

echo
echo "--- 13. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "WRAPPER_RC=$WRAPPER_RC"
echo "COMPILE_RC=$COMPILE_RC"
echo "DIRECT_RC=$DIRECT_RC"
echo "NATIVE_LINK_RC=$NATIVE_LINK_RC"
echo "CONFIGURE_RC=$CONFIGURE_RC"
echo "BUILD_RC=$BUILD_RC"

if [ -f "$TESTDIR/build/phase191" ]; then
    echo "CMAKE_EXECUTABLE=CREATED"
    file "$TESTDIR/build/phase191"
    echo "CMAKE_NATIVE_CLANG_NDK_LLD=SUCCESS"
else
    echo "CMAKE_EXECUTABLE=NOT_CREATED"
    echo "CMAKE_NATIVE_CLANG_NDK_LLD=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 191 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TESTDIR"
echo "RESULT_FILE=$HOME/pocket_pcr_studio/phase191_result.txt"
echo "=================================================="
