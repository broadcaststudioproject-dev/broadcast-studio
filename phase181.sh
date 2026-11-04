#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 181: ISOLATE BOX64 LLD ARGUMENT / LIBRARY CRASH"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"
RUNNER="$(command -v glibc-runner 2>/dev/null || true)"
BOX64="$GLIBC/bin/box64"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
BIN="$X86/bin"
SYSROOT="$X86/sysroot"
CLANG="$BIN/clang"
LLD="$BIN/ld.lld"

TESTDIR="$PWD/phase181_test"
mkdir -p "$TESTDIR"

rm -f "$TESTDIR"/*

echo
echo "--- 1. ENVIRONMENT ---"
echo "HOST=$(uname -m)"
echo "RUNNER=$RUNNER"
echo "BOX64=$BOX64"
echo "NDK=$NDK"
echo "X86=$X86"
echo "SYSROOT=$SYSROOT"
echo "CLANG=$CLANG"
echo "LLD=$LLD"

echo
echo "--- 2. BOX64 CHECK ---"
"$RUNNER" "$BOX64" --version 2>&1
BOX64_RC=$?
echo "BOX64_RC=$BOX64_RC"

echo
echo "--- 3. LLD VERSION THROUGH BOX64 ---"
"$RUNNER" "$BOX64" "$LLD" --version 2>&1
LLD_VERSION_RC=$?
echo "LLD_VERSION_RC=$LLD_VERSION_RC"

echo
echo "--- 4. CREATE TEST SOURCE ---"

cat > "$TESTDIR/test.c" <<'SRC'
int main(void)
{
    return 0;
}
SRC

echo "SOURCE=$TESTDIR/test.c"

echo
echo "--- 5. COMPILE OBJECT THROUGH BOX64 ---"

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
echo "--- 6. LOCATE BUILTINS ---"

BUILTINS="$X86/lib/clang/19/lib/linux/aarch64/libclang_rt.builtins-aarch64-android.a"

echo "BUILTINS=$BUILTINS"

if [ -f "$BUILTINS" ]; then
    echo "BUILTINS_EXISTS=YES"
else
    echo "BUILTINS_EXISTS=NO"
fi

echo
echo "--- 7. LOCATE CRT FILES ---"

CRTBEGIN="$SYSROOT/usr/lib/aarch64-linux-android/21/crtbegin_dynamic.o"
CRTEND="$SYSROOT/usr/lib/aarch64-linux-android/21/crtend_android.o"

echo "CRTBEGIN=$CRTBEGIN"
echo "CRTEND=$CRTEND"

ls -l "$CRTBEGIN" "$CRTEND" 2>&1

echo
echo "--- 8. LOCATE ANDROID LIBRARIES ---"

LIBDIR="$SYSROOT/usr/lib/aarch64-linux-android/21"

echo "LIBDIR=$LIBDIR"

ls -l "$LIBDIR/libc.so" "$LIBDIR/libdl.so" 2>&1

echo
echo "--- 9. TEST: OBJECT ONLY ---"

"$RUNNER" "$BOX64" "$LLD" \
    -EL \
    -m aarch64linux \
    -o "$TESTDIR/link_object_only" \
    "$TESTDIR/test.o" \
    2>&1

OBJECT_LINK_RC=$?

echo "OBJECT_LINK_RC=$OBJECT_LINK_RC"

if [ -f "$TESTDIR/link_object_only" ]; then
    echo "OBJECT_LINK_CREATED=YES"
    file "$TESTDIR/link_object_only"
else
    echo "OBJECT_LINK_CREATED=NO"
fi

echo
echo "--- 10. TEST: OBJECT + BUILTINS ---"

"$RUNNER" "$BOX64" "$LLD" \
    -EL \
    -m aarch64linux \
    -o "$TESTDIR/link_builtins" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    2>&1

BUILTINS_LINK_RC=$?

echo "BUILTINS_LINK_RC=$BUILTINS_LINK_RC"

if [ -f "$TESTDIR/link_builtins" ]; then
    echo "BUILTINS_LINK_CREATED=YES"
    file "$TESTDIR/link_builtins"
else
    echo "BUILTINS_LINK_CREATED=NO"
fi

echo
echo "--- 11. TEST: OBJECT + CRTBEGIN ---"

"$RUNNER" "$BOX64" "$LLD" \
    -EL \
    -m aarch64linux \
    -o "$TESTDIR/link_crtbegin" \
    "$CRTBEGIN" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    2>&1

CRTBEGIN_RC=$?

echo "CRTBEGIN_RC=$CRTBEGIN_RC"

if [ -f "$TESTDIR/link_crtbegin" ]; then
    echo "CRTBEGIN_CREATED=YES"
else
    echo "CRTBEGIN_CREATED=NO"
fi

echo
echo "--- 12. TEST: OBJECT + CRTEND ---"

"$RUNNER" "$BOX64" "$LLD" \
    -EL \
    -m aarch64linux \
    -o "$TESTDIR/link_crtend" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    "$CRTEND" \
    2>&1

CRTEND_RC=$?

echo "CRTEND_RC=$CRTEND_RC"

if [ -f "$TESTDIR/link_crtend" ]; then
    echo "CRTEND_CREATED=YES"
else
    echo "CRTEND_CREATED=NO"
fi

echo
echo "--- 13. TEST: BUILTINS + LIBC ---"

"$RUNNER" "$BOX64" "$LLD" \
    -EL \
    -m aarch64linux \
    -o "$TESTDIR/link_libc" \
    "$CRTBEGIN" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    -L"$LIBDIR" \
    -lc \
    "$CRTEND" \
    2>&1

LIBC_LINK_RC=$?

echo "LIBC_LINK_RC=$LIBC_LINK_RC"

if [ -f "$TESTDIR/link_libc" ]; then
    echo "LIBC_LINK_CREATED=YES"
    file "$TESTDIR/link_libc"
else
    echo "LIBC_LINK_CREATED=NO"
fi

echo
echo "--- 14. TEST: BUILTINS + LIBDL ---"

"$RUNNER" "$BOX64" "$LLD" \
    -EL \
    -m aarch64linux \
    -o "$TESTDIR/link_libdl" \
    "$CRTBEGIN" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    -L"$LIBDIR" \
    -ldl \
    "$CRTEND" \
    2>&1

LIBDL_LINK_RC=$?

echo "LIBDL_LINK_RC=$LIBDL_LINK_RC"

if [ -f "$TESTDIR/link_libdl" ]; then
    echo "LIBDL_LINK_CREATED=YES"
else
    echo "LIBDL_LINK_CREATED=NO"
fi

echo
echo "--- 15. TEST: BUILTINS + LIBC + LIBDL ---"

"$RUNNER" "$BOX64" "$LLD" \
    -EL \
    -m aarch64linux \
    -o "$TESTDIR/link_libc_dl" \
    "$CRTBEGIN" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    -L"$LIBDIR" \
    -lc \
    -ldl \
    "$CRTEND" \
    2>&1

LIBC_DL_RC=$?

echo "LIBC_DL_RC=$LIBC_DL_RC"

if [ -f "$TESTDIR/link_libc_dl" ]; then
    echo "LIBC_DL_CREATED=YES"
    file "$TESTDIR/link_libc_dl"
else
    echo "LIBC_DL_CREATED=NO"
fi

echo
echo "--- 16. TEST: EXACT ANDROID CRT/LIB ORDER ---"

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
    -o "$TESTDIR/link_android_exact" \
    "$CRTBEGIN" \
    -L"$X86/lib/clang/19/lib/linux/aarch64" \
    -L"$LIBDIR" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    -ldl \
    -lc \
    "$BUILTINS" \
    -ldl \
    "$CRTEND" \
    2>&1

EXACT_RC=$?

echo "EXACT_RC=$EXACT_RC"

if [ -f "$TESTDIR/link_android_exact" ]; then
    echo "EXACT_CREATED=YES"
    file "$TESTDIR/link_android_exact"
else
    echo "EXACT_CREATED=NO"
fi

echo
echo "--- 17. TEST: -l:libunwind.a ONLY ---"

UNWIND="$X86/lib/clang/19/lib/linux/aarch64/libunwind.a"

echo "UNWIND=$UNWIND"

if [ -f "$UNWIND" ]; then
    echo "UNWIND_EXISTS=YES"

    "$RUNNER" "$BOX64" "$LLD" \
        -EL \
        -m aarch64linux \
        -o "$TESTDIR/link_unwind" \
        "$TESTDIR/test.o" \
        "$BUILTINS" \
        "$UNWIND" \
        2>&1

    UNWIND_RC=$?
else
    echo "UNWIND_EXISTS=NO"
    UNWIND_RC=999
fi

echo "UNWIND_RC=$UNWIND_RC"

echo
echo "--- 18. TEST: NATIVE LD SCRIPT libc.so ---"

echo "Checking libc.so type:"
file "$SYSROOT/usr/lib/aarch64-linux-android/21/libc.so" 2>&1

echo
echo "--- 19. TEST: NATIVE LIBRARY DIRECT PATH ---"

LIBC_DIRECT="$SYSROOT/usr/lib/aarch64-linux-android/21/libc.so"
LIBDL_DIRECT="$SYSROOT/usr/lib/aarch64-linux-android/21/libdl.so"

echo "LIBC_DIRECT=$LIBC_DIRECT"
echo "LIBDL_DIRECT=$LIBDL_DIRECT"

ls -l "$LIBC_DIRECT" "$LIBDL_DIRECT" 2>&1

echo
echo "--- 20. BOX64 TRACE FOR FAILING EXACT LINK ---"

export BOX64_TRACE_FILE="$TESTDIR/box64_trace.log"
export BOX64_LOG=1

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
    -o "$TESTDIR/link_trace" \
    "$CRTBEGIN" \
    -L"$X86/lib/clang/19/lib/linux/aarch64" \
    -L"$LIBDIR" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    -ldl \
    -lc \
    "$BUILTINS" \
    -ldl \
    "$CRTEND" \
    2>&1

TRACE_RC=$?

echo "TRACE_RC=$TRACE_RC"

echo
echo "--- 21. TRACE FILE ---"

if [ -f "$TESTDIR/box64_trace.log" ]; then
    echo "TRACE_EXISTS=YES"
    wc -c "$TESTDIR/box64_trace.log"
    tail -80 "$TESTDIR/box64_trace.log" 2>/dev/null || true
else
    echo "TRACE_EXISTS=NO"
fi

echo
echo "--- 22. FINAL INVENTORY ---"

find "$TESTDIR" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort

echo
echo "--- 23. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "BOX64_RC=$BOX64_RC"
echo "LLD_VERSION_RC=$LLD_VERSION_RC"
echo "COMPILE_RC=$COMPILE_RC"
echo "OBJECT_LINK_RC=$OBJECT_LINK_RC"
echo "BUILTINS_LINK_RC=$BUILTINS_LINK_RC"
echo "CRTBEGIN_RC=$CRTBEGIN_RC"
echo "CRTEND_RC=$CRTEND_RC"
echo "LIBC_LINK_RC=$LIBC_LINK_RC"
echo "LIBDL_LINK_RC=$LIBDL_LINK_RC"
echo "LIBC_DL_RC=$LIBC_DL_RC"
echo "EXACT_RC=$EXACT_RC"
echo "UNWIND_RC=$UNWIND_RC"
echo "TRACE_RC=$TRACE_RC"

echo
echo "=================================================="
echo " PHASE 181 COMPLETE"
echo "=================================================="

echo "TESTDIR=$TESTDIR"
echo "RESULT_FILE=$PWD/phase181_result.txt"

echo "=================================================="
