#!/data/data/com.termux/files/usr/bin/bash

ROOT="$HOME/pocket_pcr_studio"
TEST="$ROOT/phase207_test"

NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

RUNNER="$PREFIX/bin/glibc-runner"
BOX64="$PREFIX/glibc/bin/box64"

CLANG="$TEST/clang-wrapper"
LLD="$TEST/ld-wrapper"

rm -rf "$TEST"
mkdir -p "$TEST"

echo "=================================================="
echo " PHASE 207: COMPILE VS LINK ISOLATION"
echo "=================================================="

cat > "$CLANG" <<EOF2
#!/data/data/com.termux/files/usr/bin/bash
exec "$RUNNER" "$BOX64" "$PRE/bin/clang" "\$@"
EOF2

cat > "$LLD" <<EOF2
#!/data/data/com.termux/files/usr/bin/bash
exec "$RUNNER" "$BOX64" "$PRE/bin/ld.lld" "\$@"
EOF2

chmod +x "$CLANG" "$LLD"

cat > "$TEST/main.c" <<'EOF2'
int main(void)
{
    return 0;
}
EOF2

echo
echo "--- 1. NDK CLANG COMPILE ---"

"$CLANG" \
  --target=aarch64-linux-android21 \
  --sysroot="$PRE/sysroot" \
  -c "$TEST/main.c" \
  -o "$TEST/main.o"

A=$?
echo "COMPILE_RC=$A"

echo
echo "--- 2. NATIVE CLANG LINK ---"

clang \
  --target=aarch64-linux-android21 \
  --sysroot="$PRE/sysroot" \
  -nostdlib \
  -nostartfiles \
  -fuse-ld="$LLD" \
  -Wl,-e,main \
  "$TEST/main.o" \
  -o "$TEST/native_link"

B=$?
echo "NATIVE_LINK_RC=$B"

echo
echo "--- 3. NDK CLANG DRIVER LINK ---"

"$CLANG" \
  --target=aarch64-linux-android21 \
  --sysroot="$PRE/sysroot" \
  -nostdlib \
  -nostartfiles \
  -fuse-ld="$LLD" \
  -Wl,-e,main \
  "$TEST/main.o" \
  -o "$TEST/ndk_link"

C=$?
echo "NDK_LINK_RC=$C"

echo
echo "--- 4. DIRECT LLD ---"

"$LLD" \
  -e main \
  "$TEST/main.o" \
  -o "$TEST/direct_link"

D=$?
echo "DIRECT_LLD_RC=$D"

echo
echo "--- 5. FILES ---"

[ -f "$TEST/main.o" ] && echo "OBJECT=YES" || echo "OBJECT=NO"
[ -f "$TEST/native_link" ] && echo "NATIVE_EXECUTABLE=YES" || echo "NATIVE_EXECUTABLE=NO"
[ -f "$TEST/ndk_link" ] && echo "NDK_EXECUTABLE=YES" || echo "NDK_EXECUTABLE=NO"
[ -f "$TEST/direct_link" ] && echo "DIRECT_EXECUTABLE=YES" || echo "DIRECT_EXECUTABLE=NO"

echo
echo "--- 6. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "COMPILE_RC=$A"
echo "NATIVE_LINK_RC=$B"
echo "NDK_LINK_RC=$C"
echo "DIRECT_LLD_RC=$D"

if [ "$B" -eq 0 ] && [ "$D" -eq 0 ]; then
    echo "LLD_PATH=WORKING"
else
    echo "LLD_PATH=FAILED"
fi

if [ "$C" -eq 0 ]; then
    echo "NDK_CLANG_DRIVER=WORKING"
else
    echo "NDK_CLANG_DRIVER=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 207 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TEST"
echo "=================================================="
