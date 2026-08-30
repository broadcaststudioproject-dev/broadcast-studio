#!/data/data/com.termux/files/usr/bin/bash
set +e

echo "=================================================="
echo " PHASE 189: NATIVE TERMUX CLANG + NDK LLD"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"
RUNNER="$PREFIX/bin/glibc-runner"
BOX64="$GLIBC/bin/box64"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

NDK_CLANG="$X86/bin/clang"
LLD="$X86/bin/ld.lld"
SYSROOT="$X86/sysroot"
RESOURCE="$X86/lib/clang/19"
RESLIB="$RESOURCE/lib/linux"

# Native ARM64 Termux compiler
NATIVE_CLANG="$(command -v clang)"

TESTDIR="$HOME/pocket_pcr_studio/phase189_test"

rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"

echo
echo "--- 1. HOST + TOOLS ---"
echo "HOST=$(uname -m)"
echo "NATIVE_CLANG=$NATIVE_CLANG"
echo "NDK_CLANG=$NDK_CLANG"
echo "LLD=$LLD"
echo "SYSROOT=$SYSROOT"

echo
echo "--- 2. NATIVE CLANG VERSION ---"

"$NATIVE_CLANG" --version 2>&1
NATIVE_CLANG_RC=$?

echo "NATIVE_CLANG_RC=$NATIVE_CLANG_RC"

echo
echo "--- 3. BOX64 LLD VERSION ---"

"$RUNNER" "$BOX64" "$LLD" --version 2>&1
LLD_RC=$?

echo "LLD_RC=$LLD_RC"

echo
echo "--- 4. CREATE LLD WRAPPER ---"

cat > "$TESTDIR/ld-wrapper" <<'WRAP'
#!/data/data/com.termux/files/usr/bin/bash

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
RUNNER="$PREFIX/bin/glibc-runner"
BOX64="$PREFIX/glibc/bin/box64"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
LLD="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/ld.lld"

exec "$RUNNER" "$BOX64" "$LLD" "$@"
WRAP

chmod +x "$TESTDIR/ld-wrapper"

echo "WRAPPER=$TESTDIR/ld-wrapper"

"$TESTDIR/ld-wrapper" --version 2>&1
WRAPPER_RC=$?

echo "WRAPPER_RC=$WRAPPER_RC"

echo
echo "--- 5. CREATE SOURCE ---"

cat > "$TESTDIR/test.c" <<'SRC'
int main(void) {
    return 0;
}
SRC

echo
echo "--- 6. NATIVE CLANG COMPILE ONLY ---"

"$NATIVE_CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -c "$TESTDIR/test.c" \
    -o "$TESTDIR/test.o" \
    2>&1

COMPILE_RC=$?

echo "COMPILE_RC=$COMPILE_RC"

if [ -f "$TESTDIR/test.o" ]; then
    echo "OBJECT=YES"
    file "$TESTDIR/test.o"
else
    echo "OBJECT=NO"
fi

echo
echo "--- 7. NATIVE CLANG DRIVER + LLD WRAPPER ---"

"$NATIVE_CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -fuse-ld="$TESTDIR/ld-wrapper" \
    -nostdlib \
    -nostartfiles \
    -Wl,-e,main \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/native_driver_link" \
    2>&1

NATIVE_LINK_RC=$?

echo "NATIVE_LINK_RC=$NATIVE_LINK_RC"

if [ -f "$TESTDIR/native_driver_link" ]; then
    echo "NATIVE_DRIVER_LINK=SUCCESS"
    file "$TESTDIR/native_driver_link"
else
    echo "NATIVE_DRIVER_LINK=FAILED"
fi

echo
echo "--- 8. NATIVE CLANG + DIRECT LLD PATH ---"

"$NATIVE_CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -fuse-ld="$TESTDIR/ld-wrapper" \
    -nostdlib \
    -nostartfiles \
    -Wl,-e,main \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/direct_style_link" \
    2>&1

DIRECT_STYLE_RC=$?

echo "DIRECT_STYLE_RC=$DIRECT_STYLE_RC"

echo
echo "--- 9. COMPARE WITH NDK CLANG UNDER BOX64 ---"

"$RUNNER" "$BOX64" "$NDK_CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -fuse-ld=lld \
    -nostdlib \
    -nostartfiles \
    -Wl,-e,main \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/ndk_driver_link" \
    2>&1

NDK_DRIVER_RC=$?

echo "NDK_DRIVER_RC=$NDK_DRIVER_RC"

if [ -f "$TESTDIR/ndk_driver_link" ]; then
    echo "NDK_DRIVER_LINK=SUCCESS"
else
    echo "NDK_DRIVER_LINK=FAILED"
fi

echo
echo "--- 10. VERBOSE NATIVE LINK ---"

"$NATIVE_CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -fuse-ld="$TESTDIR/ld-wrapper" \
    -v \
    -nostdlib \
    -nostartfiles \
    -Wl,-e,main \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/verbose_native" \
    > "$TESTDIR/verbose_native.log" 2>&1

VERBOSE_RC=$?

echo "VERBOSE_RC=$VERBOSE_RC"

echo
echo "--- 11. VERBOSE LINK HEAD ---"

head -80 "$TESTDIR/verbose_native.log" 2>/dev/null

echo
echo "--- 12. FINAL INVENTORY ---"

find "$TESTDIR" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort

echo
echo "--- 13. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "NATIVE_CLANG_RC=$NATIVE_CLANG_RC"
echo "LLD_RC=$LLD_RC"
echo "WRAPPER_RC=$WRAPPER_RC"
echo "COMPILE_RC=$COMPILE_RC"
echo "NATIVE_LINK_RC=$NATIVE_LINK_RC"
echo "DIRECT_STYLE_RC=$DIRECT_STYLE_RC"
echo "NDK_DRIVER_RC=$NDK_DRIVER_RC"
echo "VERBOSE_RC=$VERBOSE_RC"

if [ "$NATIVE_LINK_RC" = "0" ] &&
   [ -f "$TESTDIR/native_driver_link" ]; then
    echo "WORKAROUND_STATUS=SUCCESS"
else
    echo "WORKAROUND_STATUS=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 189 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TESTDIR"
echo "RESULT_FILE=$HOME/pocket_pcr_studio/phase189_result.txt"
echo "=================================================="

