#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 187: CLANG DRIVER CRASH ISOLATION"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"
RUNNER="$(command -v glibc-runner)"
BOX64="$GLIBC/bin/box64"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
BIN="$X86/bin"
SYSROOT="$X86/sysroot"

CLANG="$BIN/clang"
LLD="$BIN/ld.lld"

RESOURCE="$X86/lib/clang/19"
RESLIB="$RESOURCE/lib/linux"
LIBDIR="$SYSROOT/usr/lib/aarch64-linux-android/21"

BUILTINS="$RESLIB/libclang_rt.builtins-aarch64-android.a"
CRTBEGIN="$LIBDIR/crtbegin_dynamic.o"
CRTEND="$LIBDIR/crtend_android.o"
LIBC="$LIBDIR/libc.so"
LIBDL="$LIBDIR/libdl.so"

UNWIND=$(find "$NDK" -type f -name 'libunwind.a' 2>/dev/null | head -1)

TESTDIR="$HOME/pocket_pcr_studio/phase187_test"
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"

echo
echo "--- 1. PATHS ---"
echo "CLANG=$CLANG"
echo "LLD=$LLD"
echo "SYSROOT=$SYSROOT"
echo "BUILTINS=$BUILTINS"
echo "UNWIND=$UNWIND"

echo
echo "--- 2. CREATE SOURCE ---"

cat > "$TESTDIR/test.c" <<'SRC'
int main(void) {
    return 0;
}
SRC

echo
echo "--- 3. COMPILE ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -c "$TESTDIR/test.c" \
    -o "$TESTDIR/test.o" \
    2>&1

COMPILE_RC=$?
echo "COMPILE_RC=$COMPILE_RC"

echo
echo "--- 4. TEST A: CLANG DRIVER OBJECT -> LLD ONLY ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -fuse-ld=lld \
    -nostdlib \
    -nostartfiles \
    -Wl,-e,main \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/a" \
    2>&1

A_RC=$?
echo "A_RC=$A_RC"

echo
echo "--- 5. TEST B: ADD CRT ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -fuse-ld=lld \
    -nostdlib \
    -nostartfiles \
    -Wl,-e,main \
    "$CRTBEGIN" \
    "$TESTDIR/test.o" \
    "$CRTEND" \
    -o "$TESTDIR/b" \
    2>&1

B_RC=$?
echo "B_RC=$B_RC"

echo
echo "--- 6. TEST C: ADD BUILTINS ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -fuse-ld=lld \
    -nostdlib \
    -nostartfiles \
    -Wl,-e,main \
    "$CRTBEGIN" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    "$CRTEND" \
    -o "$TESTDIR/c" \
    2>&1

C_RC=$?
echo "C_RC=$C_RC"

echo
echo "--- 7. TEST D: ADD LIBC ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -fuse-ld=lld \
    -nostdlib \
    -nostartfiles \
    -Wl,-e,main \
    "$CRTBEGIN" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    "$UNWIND" \
    "$LIBC" \
    "$CRTEND" \
    -o "$TESTDIR/d" \
    2>&1

D_RC=$?
echo "D_RC=$D_RC"

echo
echo "--- 8. TEST E: ADD LIBDL ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -fuse-ld=lld \
    -nostdlib \
    -nostartfiles \
    -Wl,-e,main \
    "$CRTBEGIN" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    "$UNWIND" \
    "$LIBC" \
    "$LIBDL" \
    "$CRTEND" \
    -o "$TESTDIR/e" \
    2>&1

E_RC=$?
echo "E_RC=$E_RC"

echo
echo "--- 9. TEST F: NORMAL DRIVER ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -fuse-ld=lld \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/f" \
    2>&1

F_RC=$?
echo "F_RC=$F_RC"

echo
echo "--- 10. TEST G: NORMAL + EXPLICIT UNWIND ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -fuse-ld=lld \
    -unwindlib=libunwind \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/g" \
    2>&1

G_RC=$?
echo "G_RC=$G_RC"

echo
echo "--- 11. TEST H: DRIVER WITHOUT UNWIND ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -fuse-ld=lld \
    -unwindlib=none \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/h" \
    2>&1

H_RC=$?
echo "H_RC=$H_RC"

echo
echo "--- 12. TEST I: RESPONSE FILE ---"

cat > "$TESTDIR/link.rsp" <<EOF_RSP
--target=aarch64-linux-android21
--sysroot=$SYSROOT
-fuse-ld=lld
$TESTDIR/test.o
-o
$TESTDIR/i
EOF_RSP

"$RUNNER" "$BOX64" "$CLANG" \
    @"$TESTDIR/link.rsp" \
    2>&1

I_RC=$?
echo "I_RC=$I_RC"

echo
echo "--- 13. OUTPUT FILES ---"

for F in a b c d e f g h i; do
    if [ -f "$TESTDIR/$F" ]; then
        echo "$F=CREATED"
        file "$TESTDIR/$F"
    else
        echo "$F=NOT_CREATED"
    fi
done

echo
echo "--- 14. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "COMPILE_RC=$COMPILE_RC"
echo "A_RC=$A_RC"
echo "B_RC=$B_RC"
echo "C_RC=$C_RC"
echo "D_RC=$D_RC"
echo "E_RC=$E_RC"
echo "F_RC=$F_RC"
echo "G_RC=$G_RC"
echo "H_RC=$H_RC"
echo "I_RC=$I_RC"

echo
echo "=================================================="
echo " PHASE 187 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TESTDIR"
echo "RESULT_FILE=$HOME/pocket_pcr_studio/phase187_result.txt"
echo "=================================================="
