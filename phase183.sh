#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 183: NDK LINK INPUT ISOLATION"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

RUNNER="$(command -v glibc-runner 2>/dev/null || true)"
BOX64="$GLIBC/bin/box64"
CLANG="$X86/bin/clang"
LLD="$X86/bin/ld.lld"
SYSROOT="$X86/sysroot"

TESTDIR="$PWD/phase183_test"
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"

echo
echo "--- 1. ENVIRONMENT ---"
echo "HOST=$(uname -m)"
echo "RUNNER=$RUNNER"
echo "BOX64=$BOX64"
echo "CLANG=$CLANG"
echo "LLD=$LLD"
echo "SYSROOT=$SYSROOT"

echo
echo "--- 2. BASIC TOOL CHECK ---"

"$RUNNER" "$BOX64" --version 2>&1
BOX64_RC=$?
echo "BOX64_RC=$BOX64_RC"

"$RUNNER" "$BOX64" "$LLD" --version 2>&1 | head -5
LLD_VERSION_RC=${PIPESTATUS[0]}
echo "LLD_VERSION_RC=$LLD_VERSION_RC"

echo
echo "--- 3. CREATE MINIMAL OBJECT ---"

cat > "$TESTDIR/test.c" <<'SRC'
int main(void) {
    return 0;
}
SRC

"$RUNNER" "$BOX64" "$CLANG" \
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
echo "--- 4. FIND CRTBEGIN ---"

CRTBEGIN="$(find "$SYSROOT/usr/lib/aarch64-linux-android/21" \
    -name 'crtbegin_dynamic.o' \
    -type f 2>/dev/null | head -1)"

echo "CRTBEGIN=$CRTBEGIN"

if [ -n "$CRTBEGIN" ]; then
    file "$CRTBEGIN"
    CRTBEGIN_FOUND=0
else
    echo "CRTBEGIN NOT FOUND"
    CRTBEGIN_FOUND=1
fi

echo
echo "--- 5. FIND CRTEND ---"

CRTEND="$(find "$SYSROOT/usr/lib/aarch64-linux-android/21" \
    -name 'crtend_android.o' \
    -type f 2>/dev/null | head -1)"

echo "CRTEND=$CRTEND"

if [ -n "$CRTEND" ]; then
    file "$CRTEND"
    CRTEND_FOUND=0
else
    echo "CRTEND NOT FOUND"
    CRTEND_FOUND=1
fi

echo
echo "--- 6. FIND BUILTINS ---"

BUILTINS="$(find "$X86/lib/clang/19" \
    -name 'libclang_rt.builtins-aarch64-android.a' \
    -type f 2>/dev/null | head -1)"

echo "BUILTINS=$BUILTINS"

if [ -n "$BUILTINS" ]; then
    file "$BUILTINS"
    BUILTINS_FOUND=0
else
    echo "BUILTINS NOT FOUND"
    BUILTINS_FOUND=1
fi

echo
echo "--- 7. FIND LIBUNWIND ---"

LIBUNWIND="$(find "$X86" \
    -name 'libunwind.a' \
    -type f 2>/dev/null | head -10)"

echo "$LIBUNWIND"

if [ -n "$LIBUNWIND" ]; then
    UNWIND_FOUND=0
else
    echo "LIBUNWIND NOT FOUND"
    UNWIND_FOUND=1
fi

echo
echo "--- 8. FIND LIBC ---"

LIBC="$(find "$SYSROOT/usr/lib/aarch64-linux-android/21" \
    -maxdepth 1 \
    -name 'libc.so' \
    -type f 2>/dev/null | head -1)"

echo "LIBC=$LIBC"

if [ -n "$LIBC" ]; then
    file "$LIBC"
    LIBC_FOUND=0
else
    echo "LIBC NOT FOUND"
    LIBC_FOUND=1
fi

echo
echo "--- 9. FIND LIBDL ---"

LIBDL="$(find "$SYSROOT/usr/lib/aarch64-linux-android/21" \
    -maxdepth 1 \
    -name 'libdl.so' \
    -type f 2>/dev/null | head -1)"

echo "LIBDL=$LIBDL"

if [ -n "$LIBDL" ]; then
    file "$LIBDL"
    LIBDL_FOUND=0
else
    echo "LIBDL NOT FOUND"
    LIBDL_FOUND=1
fi

echo
echo "--- 10. EXACT NDK LINK SEARCH PATHS ---"

find "$SYSROOT/usr/lib/aarch64-linux-android" \
    -maxdepth 2 \
    -type d \
    2>/dev/null | sort | head -30

echo
echo "--- 11. LLD OBJECT-ONLY LINK ---"

"$RUNNER" "$BOX64" "$LLD" \
    -m aarch64linux \
    -pie \
    -e main \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/object_only" \
    2>&1

OBJECT_LINK_RC=$?

echo "OBJECT_LINK_RC=$OBJECT_LINK_RC"

if [ -f "$TESTDIR/object_only" ]; then
    echo "OBJECT_LINK_OUTPUT=YES"
    file "$TESTDIR/object_only"
else
    echo "OBJECT_LINK_OUTPUT=NO"
fi

echo
echo "--- 12. BUILTINS ONLY LINK ---"

if [ -n "$BUILTINS" ]; then

    "$RUNNER" "$BOX64" "$LLD" \
        -m aarch64linux \
        -pie \
        -e main \
        "$TESTDIR/test.o" \
        "$BUILTINS" \
        -o "$TESTDIR/link_builtins" \
        2>&1

    BUILTINS_LINK_RC=$?

else

    echo "SKIPPED: BUILTINS NOT FOUND"
    BUILTINS_LINK_RC=1

fi

echo "BUILTINS_LINK_RC=$BUILTINS_LINK_RC"

echo
echo "--- 13. CRTBEGIN + CRTEND LINK ---"

if [ -n "$CRTBEGIN" ] && [ -n "$CRTEND" ]; then

    "$RUNNER" "$BOX64" "$LLD" \
        -m aarch64linux \
        -pie \
        -e main \
        "$CRTBEGIN" \
        "$TESTDIR/test.o" \
        "$CRTEND" \
        -o "$TESTDIR/link_crt" \
        2>&1

    CRT_LINK_RC=$?

else

    echo "SKIPPED: CRT FILES MISSING"
    CRT_LINK_RC=1

fi

echo "CRT_LINK_RC=$CRT_LINK_RC"

echo
echo "--- 14. LIBC + LIBDL LINK ---"

if [ -n "$LIBC" ] && [ -n "$LIBDL" ]; then

    "$RUNNER" "$BOX64" "$LLD" \
        -m aarch64linux \
        -pie \
        -e main \
        "$TESTDIR/test.o" \
        "$LIBC" \
        "$LIBDL" \
        -o "$TESTDIR/link_libc_dl" \
        2>&1

    LIBC_DL_RC=$?

else

    echo "SKIPPED: LIBC/LIBDL MISSING"
    LIBC_DL_RC=1

fi

echo "LIBC_DL_RC=$LIBC_DL_RC"

echo
echo "--- 15. LIBUNWIND LINK ---"

if [ -n "$LIBUNWIND" ]; then

    LIBUNWIND_ONE="$(printf '%s\n' "$LIBUNWIND" | head -1)"

    echo "USING=$LIBUNWIND_ONE"

    "$RUNNER" "$BOX64" "$LLD" \
        -m aarch64linux \
        -pie \
        -e main \
        "$TESTDIR/test.o" \
        "$LIBUNWIND_ONE" \
        -o "$TESTDIR/link_unwind" \
        2>&1

    UNWIND_LINK_RC=$?

else

    echo "SKIPPED: LIBUNWIND MISSING"
    UNWIND_LINK_RC=1

fi

echo "UNWIND_LINK_RC=$UNWIND_LINK_RC"

echo
echo "--- 16. FULL MANUAL NDK LINK ---"

if [ -n "$CRTBEGIN" ] && \
   [ -n "$CRTEND" ] && \
   [ -n "$BUILTINS" ] && \
   [ -n "$LIBUNWIND" ] && \
   [ -n "$LIBC" ] && \
   [ -n "$LIBDL" ]; then

    LIBUNWIND_ONE="$(printf '%s\n' "$LIBUNWIND" | head -1)"

    "$RUNNER" "$BOX64" "$LLD" \
        -EL \
        --fix-cortex-a53-843419 \
        -z now \
        -z relro \
        -z max-page-size=16384 \
        --hash-style=both \
        --eh-frame-hdr \
        -m aarch64linux \
        -pie \
        -dynamic-linker /system/bin/linker64 \
        -o "$TESTDIR/full_manual" \
        "$CRTBEGIN" \
        -L"$X86/lib/clang/19/lib/linux/aarch64" \
        -L"$SYSROOT/usr/lib/aarch64-linux-android/21" \
        -L"$SYSROOT/usr/lib/aarch64-linux-android" \
        "$TESTDIR/test.o" \
        "$BUILTINS" \
        "$LIBUNWIND_ONE" \
        "$LIBDL" \
        "$LIBC" \
        "$BUILTINS" \
        "$LIBUNWIND_ONE" \
        "$LIBDL" \
        "$CRTEND" \
        2>&1

    FULL_LINK_RC=$?

else

    echo "SKIPPED: required NDK inputs missing"
    FULL_LINK_RC=1

fi

echo "FULL_LINK_RC=$FULL_LINK_RC"

if [ -f "$TESTDIR/full_manual" ]; then
    echo "FULL_LINK_OUTPUT=YES"
    file "$TESTDIR/full_manual"
else
    echo "FULL_LINK_OUTPUT=NO"
fi

echo
echo "--- 17. CLANG DRIVER LINK WITHOUT UNWIND ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -nostdlib \
    -nostartfiles \
    -Wl,-e,main \
    "$TESTDIR/test.o" \
    -lc \
    -ldl \
    -o "$TESTDIR/driver_nounwind" \
    2>&1

DRIVER_NOUNWIND_RC=$?

echo "DRIVER_NOUNWIND_RC=$DRIVER_NOUNWIND_RC"

echo
echo "--- 18. BOX64 LIBXML TRACE ---"

BOX64_LOG="$TESTDIR/box64_libxml.log"

BOX64_TRACE_FILE="$BOX64_LOG" \
BOX64_TRACE=1 \
"$RUNNER" "$BOX64" "$LLD" --version \
    > "$BOX64_LOG" 2>&1

TRACE_RC=$?

echo "TRACE_RC=$TRACE_RC"

grep -E \
'libxml|libc.so.6|libgcc_s|libunwind|Using native|Using emulated|Error initializing' \
"$BOX64_LOG" 2>/dev/null | head -80

echo
echo "--- 19. LIBXML FILES ---"

for f in \
    "$PREFIX/lib/libxml2.so.16.1.3" \
    "$PREFIX/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/lib/libxml2.so.2" \
    "$X86/lib/libxml2.so.2" \
    "$NDK/toolchains/llvm/prebuilt/linux-x86_64/lib/libxml2.so.2"
do
    if [ -f "$f" ]; then
        echo "FOUND: $f"
        file "$f"
    fi
done

echo
echo "--- 20. FINAL INVENTORY ---"

find "$TESTDIR" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort

echo
echo "--- 21. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "BOX64_RC=$BOX64_RC"
echo "LLD_VERSION_RC=$LLD_VERSION_RC"
echo "COMPILE_RC=$COMPILE_RC"

echo "CRTBEGIN_FOUND=$CRTBEGIN_FOUND"
echo "CRTEND_FOUND=$CRTEND_FOUND"
echo "BUILTINS_FOUND=$BUILTINS_FOUND"
echo "UNWIND_FOUND=$UNWIND_FOUND"
echo "LIBC_FOUND=$LIBC_FOUND"
echo "LIBDL_FOUND=$LIBDL_FOUND"

echo "OBJECT_LINK_RC=$OBJECT_LINK_RC"
echo "BUILTINS_LINK_RC=$BUILTINS_LINK_RC"
echo "CRT_LINK_RC=$CRT_LINK_RC"
echo "LIBC_DL_RC=$LIBC_DL_RC"
echo "UNWIND_LINK_RC=$UNWIND_LINK_RC"
echo "FULL_LINK_RC=$FULL_LINK_RC"
echo "DRIVER_NOUNWIND_RC=$DRIVER_NOUNWIND_RC"
echo "TRACE_RC=$TRACE_RC"

echo
echo "=================================================="
echo " PHASE 183 COMPLETE"
echo "=================================================="

echo "TESTDIR=$TESTDIR"
echo "RESULT_FILE=$PWD/phase183_result.txt"

echo "=================================================="

