#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 184: EXACT NDK LINK INPUT DISCOVERY"
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

TESTDIR="$HOME/pocket_pcr_studio/phase184_test"
mkdir -p "$TESTDIR"

echo
echo "--- 1. BASIC PATHS ---"
echo "PREFIX=$PREFIX"
echo "NDK=$NDK"
echo "X86=$X86"
echo "BIN=$BIN"
echo "SYSROOT=$SYSROOT"
echo "CLANG=$CLANG"
echo "LLD=$LLD"
echo "RUNNER=$RUNNER"
echo "BOX64=$BOX64"

echo
echo "--- 2. HOST ---"
uname -m
getprop ro.product.cpu.abi 2>/dev/null || true

echo
echo "--- 3. BOX64 ---"
"$RUNNER" "$BOX64" --version 2>&1
echo "BOX64_RC=$?"

echo
echo "--- 4. LLD ---"
"$RUNNER" "$BOX64" "$LLD" --version 2>&1
echo "LLD_RC=$?"

echo
echo "--- 5. CLANG RESOURCE DIRECTORY ---"
"$RUNNER" "$BOX64" "$CLANG" --print-resource-dir 2>&1
RESOURCE="$("$RUNNER" "$BOX64" "$CLANG" --print-resource-dir 2>/dev/null)"
echo "RESOURCE=$RESOURCE"

echo
echo "--- 6. NDK SYSROOT ---"
if [ -d "$SYSROOT" ]; then
    echo "SYSROOT_EXISTS=YES"
    ls -ld "$SYSROOT"
else
    echo "SYSROOT_EXISTS=NO"
fi

echo
echo "--- 7. EXACT ANDROID LIBRARY DIRECTORY ---"

LIBDIR="$SYSROOT/usr/lib/aarch64-linux-android/21"
LIBDIR2="$SYSROOT/usr/lib/aarch64-linux-android"

echo "LIBDIR=$LIBDIR"
echo "LIBDIR2=$LIBDIR2"

if [ -d "$LIBDIR" ]; then
    echo "LIBDIR_EXISTS=YES"
    ls -ld "$LIBDIR"
else
    echo "LIBDIR_EXISTS=NO"
fi

if [ -d "$LIBDIR2" ]; then
    echo "LIBDIR2_EXISTS=YES"
else
    echo "LIBDIR2_EXISTS=NO"
fi

echo
echo "--- 8. CRTBEGIN SEARCH ---"

find "$SYSROOT" "$X86" \
    -type f -o -type l \
    2>/dev/null | grep -E '/crtbegin(_dynamic)?\.o$' | head -50

echo
echo "--- 9. CRTEND SEARCH ---"

find "$SYSROOT" "$X86" \
    -type f -o -type l \
    2>/dev/null | grep -E '/crtend(_android)?\.o$' | head -50

echo
echo "--- 10. BUILTINS SEARCH ---"

find "$X86" \
    -type f -o -type l \
    2>/dev/null | grep 'libclang_rt.builtins-aarch64-android.a' | head -50

echo
echo "--- 11. LIBUNWIND SEARCH ---"

find "$X86" "$SYSROOT" \
    -type f -o -type l \
    2>/dev/null | grep -E '/libunwind\.(a|so)(\..*)?$' | head -50

echo
echo "--- 12. LIBC SEARCH ---"

find "$SYSROOT" \
    -type f -o -type l \
    2>/dev/null | grep -E '/libc\.(a|so)(\..*)?$' | head -50

echo
echo "--- 13. LIBDL SEARCH ---"

find "$SYSROOT" \
    -type f -o -type l \
    2>/dev/null | grep -E '/libdl\.(a|so)(\..*)?$' | head -50

echo
echo "--- 14. LIBM SEARCH ---"

find "$SYSROOT" \
    -type f -o -type l \
    2>/dev/null | grep -E '/libm\.(a|so)(\..*)?$' | head -50

echo
echo "--- 15. CRT + LIB DIRECTORY LISTING ---"

if [ -d "$LIBDIR" ]; then
    ls -la "$LIBDIR" 2>/dev/null | head -100
fi

echo
echo "--- 16. CLANG RESOURCE LIB DIRECTORY ---"

RESLIB="$RESOURCE/lib/linux/aarch64"

echo "RESLIB=$RESLIB"

if [ -d "$RESLIB" ]; then
    echo "RESLIB_EXISTS=YES"
    ls -la "$RESLIB" 2>/dev/null | head -100
else
    echo "RESLIB_EXISTS=NO"
fi

echo
echo "--- 17. BUILTINS EXACT PATH CHECK ---"

BUILTINS="$RESLIB/libclang_rt.builtins-aarch64-android.a"

echo "BUILTINS=$BUILTINS"

if [ -f "$BUILTINS" ]; then
    echo "BUILTINS_EXISTS=YES"
    ls -lh "$BUILTINS"
    file "$BUILTINS"
else
    echo "BUILTINS_EXISTS=NO"
fi

echo
echo "--- 18. LIBUNWIND EXACT PATH CHECK ---"

UNWIND="$RESLIB/libunwind.a"

echo "UNWIND=$UNWIND"

if [ -f "$UNWIND" ]; then
    echo "UNWIND_EXISTS=YES"
    ls -lh "$UNWIND"
    file "$UNWIND"
else
    echo "UNWIND_EXISTS=NO"
fi

echo
echo "--- 19. CRT EXACT PATH CHECK ---"

CRTBEGIN="$LIBDIR/crtbegin_dynamic.o"
CRTEND="$LIBDIR/crtend_android.o"

echo "CRTBEGIN=$CRTBEGIN"
echo "CRTEND=$CRTEND"

if [ -f "$CRTBEGIN" ]; then
    echo "CRTBEGIN_EXISTS=YES"
    ls -lh "$CRTBEGIN"
    file "$CRTBEGIN"
else
    echo "CRTBEGIN_EXISTS=NO"
fi

if [ -f "$CRTEND" ]; then
    echo "CRTEND_EXISTS=YES"
    ls -lh "$CRTEND"
    file "$CRTEND"
else
    echo "CRTEND_EXISTS=NO"
fi

echo
echo "--- 20. LIBC EXACT PATH CHECK ---"

LIBC="$LIBDIR/libc.so"
LIBDL="$LIBDIR/libdl.so"

echo "LIBC=$LIBC"
echo "LIBDL=$LIBDL"

if [ -f "$LIBC" ]; then
    echo "LIBC_EXISTS=YES"
    ls -lh "$LIBC"
    file "$LIBC"
else
    echo "LIBC_EXISTS=NO"
fi

if [ -f "$LIBDL" ]; then
    echo "LIBDL_EXISTS=YES"
    ls -lh "$LIBDL"
    file "$LIBDL"
else
    echo "LIBDL_EXISTS=NO"
fi

echo
echo "--- 21. CREATE TEST OBJECT ---"

cat > "$TESTDIR/test.c" <<'SRC'
int main(void) {
    return 0;
}
SRC

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    -c "$TESTDIR/test.c" \
    -o "$TESTDIR/test.o" 2>&1

COMPILE_RC=$?

echo "COMPILE_RC=$COMPILE_RC"

if [ -f "$TESTDIR/test.o" ]; then
    echo "OBJECT_EXISTS=YES"
    file "$TESTDIR/test.o"
else
    echo "OBJECT_EXISTS=NO"
fi

echo
echo "--- 22. LLD OBJECT-ONLY LINK ---"

"$RUNNER" "$BOX64" "$LLD" \
    -m aarch64linux \
    -pie \
    -e main \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/object_only" 2>&1

OBJECT_LINK_RC=$?

echo "OBJECT_LINK_RC=$OBJECT_LINK_RC"

if [ -f "$TESTDIR/object_only" ]; then
    echo "OBJECT_LINK_CREATED=YES"
    file "$TESTDIR/object_only"
else
    echo "OBJECT_LINK_CREATED=NO"
fi

echo
echo "--- 23. BOX64 LIBXML DIAGNOSTIC ---"

BOX64_TRACE="$TESTDIR/box64_libxml.log"

BOX64_TRACE_FILE="$BOX64_TRACE" \
"$RUNNER" "$BOX64" "$LLD" --version \
2>&1 | tee "$BOX64_TRACE"

echo "BOX64_TRACE_RC=${PIPESTATUS[0]}"

echo
echo "--- 24. LIBXML PATHS ---"

find "$PREFIX" "$NDK" \
    -type f -o -type l \
    2>/dev/null | grep -E '/libxml2\.so(\.|$)' | head -100

echo
echo "--- 25. LIBXML FILE TYPES ---"

for F in \
    "$PREFIX/lib/libxml2.so.16.1.3" \
    "$PREFIX/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/lib/libxml2.so.2" \
    "$X86/lib/libxml2.so.2"
do
    if [ -e "$F" ]; then
        echo
        echo "FOUND: $F"
        file "$F"
    fi
done

echo
echo "--- 26. ENVIRONMENT ---"

env | grep -E '^(LD_LIBRARY_PATH|BOX64|BOX86|PREFIX|PATH)=' | sort || true

echo
echo "--- 27. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "BOX64_RC=0"
echo "RESOURCE=$RESOURCE"
echo "SYSROOT_EXISTS=$([ -d "$SYSROOT" ] && echo YES || echo NO)"
echo "LIBDIR_EXISTS=$([ -d "$LIBDIR" ] && echo YES || echo NO)"
echo "BUILTINS_EXISTS=$([ -f "$BUILTINS" ] && echo YES || echo NO)"
echo "UNWIND_EXISTS=$([ -f "$UNWIND" ] && echo YES || echo NO)"
echo "CRTBEGIN_EXISTS=$([ -f "$CRTBEGIN" ] && echo YES || echo NO)"
echo "CRTEND_EXISTS=$([ -f "$CRTEND" ] && echo YES || echo NO)"
echo "LIBC_EXISTS=$([ -f "$LIBC" ] && echo YES || echo NO)"
echo "LIBDL_EXISTS=$([ -f "$LIBDL" ] && echo YES || echo NO)"
echo "COMPILE_RC=$COMPILE_RC"
echo "OBJECT_LINK_RC=$OBJECT_LINK_RC"

echo
echo "=================================================="
echo " PHASE 184 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TESTDIR"
echo "RESULT_FILE=$HOME/pocket_pcr_studio/phase184_result.txt"
echo "=================================================="
