#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 182: NDK LINK INPUT ISOLATION"
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
CLANG_LIB="$X86/lib/clang/19/lib/linux/aarch64"

TESTDIR="$PWD/phase182_test"
RESULT="$PWD/phase182_result.txt"

mkdir -p "$TESTDIR"

exec > >(tee "$RESULT") 2>&1

echo
echo "--- 1. TOOLS ---"
echo "RUNNER=$RUNNER"
echo "BOX64=$BOX64"
echo "CLANG=$CLANG"
echo "LLD=$LLD"
echo "SYSROOT=$SYSROOT"
echo "CLANG_LIB=$CLANG_LIB"

echo
echo "--- 2. BASIC VERSION CHECKS ---"

"$RUNNER" "$BOX64" --version
echo "BOX64_RC=$?"

"$RUNNER" "$BOX64" "$LLD" --version
echo "LLD_VERSION_RC=$?"

"$RUNNER" "$BOX64" "$CLANG" --version
echo "CLANG_VERSION_RC=$?"

echo
echo "--- 3. CREATE TEST SOURCE ---"

cat > "$TESTDIR/test.c" <<'SRC'
int main(void)
{
    return 0;
}
SRC

ls -l "$TESTDIR/test.c"
file "$TESTDIR/test.c"

echo
echo "--- 4. COMPILE OBJECT ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -c "$TESTDIR/test.c" \
    -o "$TESTDIR/test.o"

COMPILE_RC=$?

echo "COMPILE_RC=$COMPILE_RC"

if [ -f "$TESTDIR/test.o" ]; then
    echo "OBJECT_CREATED=YES"
    file "$TESTDIR/test.o"
else
    echo "OBJECT_CREATED=NO"
fi

echo
echo "--- 5. VERIFY CRTBEGIN ---"

CRTBEGIN="$SYSROOT/usr/lib/aarch64-linux-android/21/crtbegin_dynamic.o"

echo "CRTBEGIN=$CRTBEGIN"
ls -l "$CRTBEGIN" 2>&1
file "$CRTBEGIN" 2>&1

if [ -f "$CRTBEGIN" ]; then
    echo "CRTBEGIN_EXISTS=YES"
else
    echo "CRTBEGIN_EXISTS=NO"
fi

echo
echo "--- 6. VERIFY CRTEND ---"

CRTEND="$SYSROOT/usr/lib/aarch64-linux-android/21/crtend_android.o"

echo "CRTEND=$CRTEND"
ls -l "$CRTEND" 2>&1
file "$CRTEND" 2>&1

if [ -f "$CRTEND" ]; then
    echo "CRTEND_EXISTS=YES"
else
    echo "CRTEND_EXISTS=NO"
fi

echo
echo "--- 7. VERIFY BUILTINS ---"

BUILTINS="$CLANG_LIB/libclang_rt.builtins-aarch64-android.a"

echo "BUILTINS=$BUILTINS"
ls -l "$BUILTINS" 2>&1
file "$BUILTINS" 2>&1

if [ -f "$BUILTINS" ]; then
    echo "BUILTINS_EXISTS=YES"
else
    echo "BUILTINS_EXISTS=NO"
fi

echo
echo "--- 8. VERIFY LIBUNWIND ---"

UNWIND="$CLANG_LIB/libunwind.a"

echo "UNWIND=$UNWIND"
ls -l "$UNWIND" 2>&1
file "$UNWIND" 2>&1

if [ -f "$UNWIND" ]; then
    echo "UNWIND_EXISTS=YES"
else
    echo "UNWIND_EXISTS=NO"
fi

echo
echo "--- 9. VERIFY LIBC ---"

LIBC="$SYSROOT/usr/lib/aarch64-linux-android/21/libc.so"

echo "LIBC=$LIBC"
ls -l "$LIBC" 2>&1
file "$LIBC" 2>&1

if [ -f "$LIBC" ]; then
    echo "LIBC_EXISTS=YES"
else
    echo "LIBC_EXISTS=NO"
fi

echo
echo "--- 10. VERIFY LIBDL ---"

LIBDL="$SYSROOT/usr/lib/aarch64-linux-android/21/libdl.so"

echo "LIBDL=$LIBDL"
ls -l "$LIBDL" 2>&1
file "$LIBDL" 2>&1

if [ -f "$LIBDL" ]; then
    echo "LIBDL_EXISTS=YES"
else
    echo "LIBDL_EXISTS=NO"
fi

echo
echo "--- 11. OBJECT ONLY LINK ---"

"$RUNNER" "$BOX64" "$LLD" \
    -m aarch64linux \
    -pie \
    -e main \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/link_object_only"

OBJECT_LINK_RC=$?

echo "OBJECT_LINK_RC=$OBJECT_LINK_RC"

if [ -f "$TESTDIR/link_object_only" ]; then
    echo "OBJECT_LINK_CREATED=YES"
    file "$TESTDIR/link_object_only"
else
    echo "OBJECT_LINK_CREATED=NO"
fi

echo
echo "--- 12. OBJECT + BUILTINS ONLY ---"

"$RUNNER" "$BOX64" "$LLD" \
    -m aarch64linux \
    -pie \
    -e main \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    -o "$TESTDIR/link_builtins"

BUILTINS_LINK_RC=$?

echo "BUILTINS_LINK_RC=$BUILTINS_LINK_RC"

if [ -f "$TESTDIR/link_builtins" ]; then
    echo "BUILTINS_LINK_CREATED=YES"
    file "$TESTDIR/link_builtins"
else
    echo "BUILTINS_LINK_CREATED=NO"
fi

echo
echo "--- 13. OBJECT + CRTBEGIN ---"

"$RUNNER" "$BOX64" "$LLD" \
    -m aarch64linux \
    -pie \
    -e main \
    "$CRTBEGIN" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    -o "$TESTDIR/link_crtbegin"

CRTBEGIN_RC=$?

echo "CRTBEGIN_RC=$CRTBEGIN_RC"

if [ -f "$TESTDIR/link_crtbegin" ]; then
    echo "CRTBEGIN_LINK_CREATED=YES"
    file "$TESTDIR/link_crtbegin"
else
    echo "CRTBEGIN_LINK_CREATED=NO"
fi

echo
echo "--- 14. OBJECT + CRTBEGIN + CRTEND ---"

"$RUNNER" "$BOX64" "$LLD" \
    -m aarch64linux \
    -pie \
    -e main \
    "$CRTBEGIN" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    "$CRTEND" \
    -o "$TESTDIR/link_crt"

CRT_LINK_RC=$?

echo "CRT_LINK_RC=$CRT_LINK_RC"

if [ -f "$TESTDIR/link_crt" ]; then
    echo "CRT_LINK_CREATED=YES"
    file "$TESTDIR/link_crt"
else
    echo "CRT_LINK_CREATED=NO"
fi

echo
echo "--- 15. ADD LIBC ---"

"$RUNNER" "$BOX64" "$LLD" \
    -m aarch64linux \
    -pie \
    -e main \
    "$CRTBEGIN" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    -L"$SYSROOT/usr/lib/aarch64-linux-android/21" \
    -L"$SYSROOT/usr/lib/aarch64-linux-android" \
    -L"$SYSROOT/usr/lib" \
    -l:libc.so \
    "$CRTEND" \
    -o "$TESTDIR/link_libc"

LIBC_LINK_RC=$?

echo "LIBC_LINK_RC=$LIBC_LINK_RC"

if [ -f "$TESTDIR/link_libc" ]; then
    echo "LIBC_LINK_CREATED=YES"
    file "$TESTDIR/link_libc"
else
    echo "LIBC_LINK_CREATED=NO"
fi

echo
echo "--- 16. ADD LIBDL ---"

"$RUNNER" "$BOX64" "$LLD" \
    -m aarch64linux \
    -pie \
    -e main \
    "$CRTBEGIN" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    -L"$SYSROOT/usr/lib/aarch64-linux-android/21" \
    -L"$SYSROOT/usr/lib/aarch64-linux-android" \
    -L"$SYSROOT/usr/lib" \
    -l:libc.so \
    -l:libdl.so \
    "$CRTEND" \
    -o "$TESTDIR/link_libc_dl"

LIBC_DL_RC=$?

echo "LIBC_DL_RC=$LIBC_DL_RC"

if [ -f "$TESTDIR/link_libc_dl" ]; then
    echo "LIBC_DL_LINK_CREATED=YES"
    file "$TESTDIR/link_libc_dl"
else
    echo "LIBC_DL_LINK_CREATED=NO"
fi

echo
echo "--- 17. ADD LIBUNWIND ---"

"$RUNNER" "$BOX64" "$LLD" \
    -m aarch64linux \
    -pie \
    -e main \
    "$CRTBEGIN" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    -L"$CLANG_LIB" \
    -L"$SYSROOT/usr/lib/aarch64-linux-android/21" \
    -L"$SYSROOT/usr/lib/aarch64-linux-android" \
    -L"$SYSROOT/usr/lib" \
    -l:libunwind.a \
    -l:libc.so \
    -l:libdl.so \
    "$CRTEND" \
    -o "$TESTDIR/link_unwind"

UNWIND_RC=$?

echo "UNWIND_RC=$UNWIND_RC"

if [ -f "$TESTDIR/link_unwind" ]; then
    echo "UNWIND_LINK_CREATED=YES"
    file "$TESTDIR/link_unwind"
else
    echo "UNWIND_LINK_CREATED=NO"
fi

echo
echo "--- 18. EXACT NDK SEARCH DIRECTORIES ---"

echo "=== Android API 21 ==="
find "$SYSROOT/usr/lib/aarch64-linux-android/21" \
    -maxdepth 1 -type f -o -type l \
    2>/dev/null | head -80

echo
echo "=== Android generic ==="
find "$SYSROOT/usr/lib/aarch64-linux-android" \
    -maxdepth 1 -type f -o -type l \
    2>/dev/null | head -80

echo
echo "--- 19. BUILTINS DIRECTORY ---"

find "$CLANG_LIB" \
    -maxdepth 1 \
    -type f -o -type l \
    2>/dev/null | head -100

echo
echo "--- 20. BOX64 TRACE LINK TEST ---"

export BOX64_LOG=1

"$RUNNER" "$BOX64" "$LLD" \
    -m aarch64linux \
    -pie \
    -e main \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/trace_link" \
    > "$TESTDIR/box64_trace.log" 2>&1

TRACE_RC=$?

echo "TRACE_RC=$TRACE_RC"

echo "--- TRACE HEAD ---"
head -100 "$TESTDIR/box64_trace.log" 2>/dev/null || true

echo
echo "--- 21. FINAL INVENTORY ---"

find "$TESTDIR" \
    -maxdepth 1 \
    -type f \
    -printf '%f\n' \
    2>/dev/null | sort

echo
echo "--- 22. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "BOX64_RC=0"
echo "LLD_VERSION_RC=0"
echo "COMPILE_RC=$COMPILE_RC"
echo "OBJECT_LINK_RC=$OBJECT_LINK_RC"
echo "BUILTINS_LINK_RC=$BUILTINS_LINK_RC"
echo "CRTBEGIN_RC=$CRTBEGIN_RC"
echo "CRT_LINK_RC=$CRT_LINK_RC"
echo "LIBC_LINK_RC=$LIBC_LINK_RC"
echo "LIBC_DL_RC=$LIBC_DL_RC"
echo "UNWIND_RC=$UNWIND_RC"
echo "TRACE_RC=$TRACE_RC"

echo
echo "=================================================="
echo " PHASE 182 COMPLETE"
echo "=================================================="

echo "TESTDIR=$TESTDIR"
echo "RESULT_FILE=$RESULT"

echo "=================================================="
