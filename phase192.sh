#!/data/data/com.termux/files/usr/bin/bash
set +e

echo "=================================================="
echo " PHASE 192: INJECT CORRECT AARCH64 LIBUNWIND PATH"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
RUNNER="$PREFIX/bin/glibc-runner"
BOX64="$PREFIX/glibc/bin/box64"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

NATIVE_CLANG="$PREFIX/bin/clang"
LLD="$X86/bin/ld.lld"

SYSROOT="$X86/sysroot"
RESOURCE="$X86/lib/clang/19"
RESLIB="$RESOURCE/lib/linux"

UNWIND_DIR="$RESLIB/aarch64"
UNWIND="$UNWIND_DIR/libunwind.a"

TESTDIR="$HOME/pocket_pcr_studio/phase192_test"

rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"

echo
echo "--- 1. PATHS ---"
echo "HOST=$(uname -m)"
echo "NATIVE_CLANG=$NATIVE_CLANG"
echo "LLD=$LLD"
echo "SYSROOT=$SYSROOT"
echo "UNWIND_DIR=$UNWIND_DIR"
echo "UNWIND=$UNWIND"

echo
echo "--- 2. VERIFY LIBUNWIND ---"

if [ -f "$UNWIND" ]; then
    echo "UNWIND_EXISTS=YES"
    file "$UNWIND"
    ls -lh "$UNWIND"
else
    echo "UNWIND_EXISTS=NO"
fi

echo
echo "--- 3. CREATE SMART LLD WRAPPER ---"

WRAPPER="$TESTDIR/ld-wrapper"

cat > "$WRAPPER" <<WRAP
#!/data/data/com.termux/files/usr/bin/bash

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

RUNNER="\$PREFIX/bin/glibc-runner"
BOX64="\$PREFIX/glibc/bin/box64"

NDK="\$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="\$NDK/toolchains/llvm/prebuilt/linux-x86_64"

LLD="\$X86/bin/ld.lld"

UNWIND_DIR="\$X86/lib/clang/19/lib/linux/aarch64"

exec "\$RUNNER" "\$BOX64" "\$LLD" \
    "-L\$UNWIND_DIR" \
    "\$@"
WRAP

chmod +x "$WRAPPER"

echo "WRAPPER=$WRAPPER"
cat "$WRAPPER"

echo
echo "--- 4. TEST WRAPPER ---"

"$WRAPPER" --version 2>&1
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

"$NATIVE_CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
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
echo "--- 7. TEST A: NORMAL NATIVE CLANG + WRAPPER ---"

"$NATIVE_CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -fuse-ld="$WRAPPER" \
    "$TESTDIR/main.o" \
    -o "$TESTDIR/a" \
    2>&1

A_RC=$?

echo "A_RC=$A_RC"

if [ -f "$TESTDIR/a" ]; then
    echo "A_CREATED=YES"
    file "$TESTDIR/a"
else
    echo "A_CREATED=NO"
fi

echo
echo "--- 8. TEST B: EXPLICIT LIBUNWIND ---"

"$NATIVE_CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -fuse-ld="$WRAPPER" \
    -unwindlib=libunwind \
    "$TESTDIR/main.o" \
    -o "$TESTDIR/b" \
    2>&1

B_RC=$?

echo "B_RC=$B_RC"

if [ -f "$TESTDIR/b" ]; then
    echo "B_CREATED=YES"
    file "$TESTDIR/b"
else
    echo "B_CREATED=NO"
fi

echo
echo "--- 9. TEST C: CMAKE STYLE -l:libunwind.a ---"

"$NATIVE_CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -fuse-ld="$WRAPPER" \
    -nostdlib \
    -nostartfiles \
    -Wl,-e,main \
    "$TESTDIR/main.o" \
    -l:libunwind.a \
    -o "$TESTDIR/c" \
    2>&1

C_RC=$?

echo "C_RC=$C_RC"

if [ -f "$TESTDIR/c" ]; then
    echo "C_CREATED=YES"
    file "$TESTDIR/c"
else
    echo "C_CREATED=NO"
fi

echo
echo "--- 10. TEST D: EXACT CMAKE FLAGS ---"

"$NATIVE_CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    --target=aarch64-linux-android21 \
    -O3 \
    -DNDEBUG \
    -fuse-ld="$WRAPPER" \
    "$TESTDIR/main.o" \
    -o "$TESTDIR/d" \
    2>&1

D_RC=$?

echo "D_RC=$D_RC"

if [ -f "$TESTDIR/d" ]; then
    echo "D_CREATED=YES"
    file "$TESTDIR/d"
else
    echo "D_CREATED=NO"
fi

echo
echo "--- 11. FINAL INVENTORY ---"

for F in a b c d; do
    if [ -f "$TESTDIR/$F" ]; then
        echo "$F=CREATED"
    else
        echo "$F=NOT_CREATED"
    fi
done

echo
echo "--- 12. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "WRAPPER_RC=$WRAPPER_RC"
echo "COMPILE_RC=$COMPILE_RC"
echo "A_RC=$A_RC"
echo "B_RC=$B_RC"
echo "C_RC=$C_RC"
echo "D_RC=$D_RC"

if [ -f "$TESTDIR/c" ]; then
    echo "LIBUNWIND_LINK=SUCCESS"
else
    echo "LIBUNWIND_LINK=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 192 COMPLETE"
echo "=================================================="

echo "TESTDIR=$TESTDIR"
echo "RESULT_FILE=$HOME/pocket_pcr_studio/phase192_result.txt"

echo "=================================================="
