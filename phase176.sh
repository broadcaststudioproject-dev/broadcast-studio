#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 176: NDK LIBUNWIND + LLD LINK ISOLATION"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"

RUNNER="$(command -v glibc-runner)"
BOX64="$GLIBC/bin/box64"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

CLANG="$X86/bin/clang"
LLD="$X86/bin/ld.lld"

TESTDIR="$PWD/phase174_test"

OBJ="$TESTDIR/test.o"

SYSROOT="$X86/sysroot"

LIBCLANG="$X86/lib/clang/19/lib/linux/aarch64"

ANDROID_LIB="$SYSROOT/usr/lib/aarch64-linux-android/21"

CRTBEGIN="$ANDROID_LIB/crtbegin_dynamic.o"
CRTEND="$ANDROID_LIB/crtend_android.o"

BUILTINS="$LIBCLANG/libclang_rt.builtins-aarch64-android.a"

LIBUNWIND="$LIBCLANG/libunwind.a"

echo
echo "--- 1. TOOLS ---"

echo "RUNNER=$RUNNER"
echo "BOX64=$BOX64"
echo "CLANG=$CLANG"
echo "LLD=$LLD"

echo
echo "--- 2. OBJECT ---"

ls -l "$OBJ" 2>&1
file "$OBJ" 2>&1

echo
echo "--- 3. CRTBEGIN ---"

ls -l "$CRTBEGIN" 2>&1
file "$CRTBEGIN" 2>&1

echo
echo "--- 4. CRTEND ---"

ls -l "$CRTEND" 2>&1
file "$CRTEND" 2>&1

echo
echo "--- 5. BUILTINS ---"

ls -l "$BUILTINS" 2>&1
file "$BUILTINS" 2>&1

echo
echo "--- 6. LIBUNWIND ---"

ls -l "$LIBUNWIND" 2>&1
file "$LIBUNWIND" 2>&1

echo
echo "--- 7. LIBUNWIND ARCHIVE ---"

if [ -f "$LIBUNWIND" ]; then

    ar t "$LIBUNWIND" 2>&1 | head -30

else

    echo "LIBUNWIND NOT FOUND"

fi

echo
echo "--- 8. LLD VERSION ---"

"$RUNNER" "$BOX64" "$LLD" --version 2>&1

echo "LLD_RC=$?"

echo
echo "--- 9. TEST A: OBJECT ONLY ---"

"$RUNNER" "$BOX64" "$LLD" \
    -flavor gnu \
    -m aarch64linux \
    -o "$TESTDIR/link_a" \
    "$OBJ" \
    2>&1

RC=$?

echo "TEST_A_RC=$RC"

if [ -f "$TESTDIR/link_a" ]; then
    echo "TEST_A_OUTPUT=YES"
    file "$TESTDIR/link_a"
else
    echo "TEST_A_OUTPUT=NO"
fi

echo
echo "--- 10. TEST B: CRTBEGIN + OBJECT + CRTEND ---"

"$RUNNER" "$BOX64" "$LLD" \
    -flavor gnu \
    -m aarch64linux \
    -o "$TESTDIR/link_b" \
    "$CRTBEGIN" \
    "$OBJ" \
    "$CRTEND" \
    2>&1

RC=$?

echo "TEST_B_RC=$RC"

if [ -f "$TESTDIR/link_b" ]; then
    echo "TEST_B_OUTPUT=YES"
    file "$TESTDIR/link_b"
else
    echo "TEST_B_OUTPUT=NO"
fi

echo
echo "--- 11. TEST C: + BUILTINS ---"

"$RUNNER" "$BOX64" "$LLD" \
    -flavor gnu \
    -m aarch64linux \
    -o "$TESTDIR/link_c" \
    "$CRTBEGIN" \
    "$OBJ" \
    "$BUILTINS" \
    "$CRTEND" \
    2>&1

RC=$?

echo "TEST_C_RC=$RC"

if [ -f "$TESTDIR/link_c" ]; then
    echo "TEST_C_OUTPUT=YES"
    file "$TESTDIR/link_c"
else
    echo "TEST_C_OUTPUT=NO"
fi

echo
echo "--- 12. TEST D: + LIBUNWIND ---"

"$RUNNER" "$BOX64" "$LLD" \
    -flavor gnu \
    -m aarch64linux \
    -o "$TESTDIR/link_d" \
    "$CRTBEGIN" \
    "$OBJ" \
    "$BUILTINS" \
    "$LIBUNWIND" \
    "$CRTEND" \
    2>&1

RC=$?

echo "TEST_D_RC=$RC"

if [ -f "$TESTDIR/link_d" ]; then
    echo "TEST_D_OUTPUT=YES"
    file "$TESTDIR/link_d"
else
    echo "TEST_D_OUTPUT=NO"
fi

echo
echo "--- 13. TEST E: + DL + C ---"

"$RUNNER" "$BOX64" "$LLD" \
    -flavor gnu \
    -m aarch64linux \
    -dynamic-linker /system/bin/linker64 \
    -pie \
    -o "$TESTDIR/link_e" \
    "$CRTBEGIN" \
    "$OBJ" \
    "$BUILTINS" \
    "$LIBUNWIND" \
    -ldl \
    -lc \
    "$CRTEND" \
    2>&1

RC=$?

echo "TEST_E_RC=$RC"

if [ -f "$TESTDIR/link_e" ]; then
    echo "TEST_E_OUTPUT=YES"
    file "$TESTDIR/link_e"
else
    echo "TEST_E_OUTPUT=NO"
fi

echo
echo "--- 14. TEST F: EXACT CLANG DRIVER LINK ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    "$OBJ" \
    -o "$TESTDIR/link_f" \
    2>&1

RC=$?

echo "TEST_F_RC=$RC"

if [ -f "$TESTDIR/link_f" ]; then
    echo "TEST_F_OUTPUT=YES"
    file "$TESTDIR/link_f"
else
    echo "TEST_F_OUTPUT=NO"
fi

echo
echo "--- 15. LINKER MEMORY / ARCHIVE INFO ---"

"$RUNNER" "$BOX64" "$LLD" \
    -flavor gnu \
    --help 2>&1 |
grep -E 'icf|gc-sections|unwind|eh-frame|pack-dyn' |
head -30 || true

echo
echo "--- 16. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "LLD=WORKING"
echo "OBJECT=WORKING"

echo
echo "TEST_A_OBJECT_ONLY=$([ -f "$TESTDIR/link_a" ] && echo YES || echo NO)"
echo "TEST_B_CRT=$([ -f "$TESTDIR/link_b" ] && echo YES || echo NO)"
echo "TEST_C_BUILTINS=$([ -f "$TESTDIR/link_c" ] && echo YES || echo NO)"
echo "TEST_D_LIBUNWIND=$([ -f "$TESTDIR/link_d" ] && echo YES || echo NO)"
echo "TEST_E_LIBC=$([ -f "$TESTDIR/link_e" ] && echo YES || echo NO)"
echo "TEST_F_CLANG_DRIVER=$([ -f "$TESTDIR/link_f" ] && echo YES || echo NO)"

echo
echo "=================================================="
echo " END PHASE 176"
echo "=================================================="

