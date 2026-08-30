#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 180: ISOLATED BOX64 + NDK LINKER DIAGNOSTIC"
echo "=================================================="

set +e

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

CLANG="$X86/bin/clang"
CLANGXX="$X86/bin/clang++"
LLD="$X86/bin/ld.lld"

SYSROOT="$X86/sysroot"
RESOURCE="$X86/lib/clang/19"
BUILTINS="$RESOURCE/lib/linux/libclang_rt.builtins-aarch64-android.a"
UNWIND="$RESOURCE/lib/linux/libunwind.a"

RUNNER="$(command -v glibc-runner 2>/dev/null || true)"
BOX64="$GLIBC/bin/box64"

TESTDIR="$HOME/pocket_pcr_studio/phase180_test"
mkdir -p "$TESTDIR"

RESULT="$HOME/pocket_pcr_studio/phase180_result.txt"

exec > >(tee "$RESULT") 2>&1

echo
echo "--- 1. BASIC ENVIRONMENT ---"
echo "HOST=$(uname -m)"
echo "PREFIX=$PREFIX"
echo "GLIBC=$GLIBC"
echo "RUNNER=$RUNNER"
echo "BOX64=$BOX64"
echo "NDK=$NDK"
echo "X86=$X86"
echo "CLANG=$CLANG"
echo "LLD=$LLD"

echo
echo "--- 2. TOOL FILE CHECK ---"
ls -l "$CLANG" 2>&1
ls -l "$CLANGXX" 2>&1
ls -l "$LLD" 2>&1
ls -l "$BUILTINS" 2>&1
ls -l "$UNWIND" 2>&1

echo
echo "--- 3. BOX64 VERSION ---"
"$RUNNER" "$BOX64" --version 2>&1
echo "BOX64_RC=$?"

echo
echo "--- 4. CLANG VERSION ---"
"$RUNNER" "$BOX64" "$CLANG" --version 2>&1
echo "CLANG_VERSION_RC=$?"

echo
echo "--- 5. LLD VERSION THROUGH RUNNER + BOX64 ---"
"$RUNNER" "$BOX64" "$LLD" --version 2>&1
echo "LLD_VERSION_RC=$?"

echo
echo "--- 6. CREATE MINIMAL SOURCE ---"

cat > "$TESTDIR/test.c" <<'SRC'
int main(void)
{
    return 0;
}
SRC

echo "SOURCE=$TESTDIR/test.c"
ls -l "$TESTDIR/test.c"

echo
echo "--- 7. COMPILE ONLY ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -c "$TESTDIR/test.c" \
    -o "$TESTDIR/test.o"

COMPILE_RC=$?

echo "COMPILE_RC=$COMPILE_RC"

if [ -f "$TESTDIR/test.o" ]; then
    echo "OBJECT=YES"
    file "$TESTDIR/test.o"
else
    echo "OBJECT=NO"
fi

echo
echo "--- 8. DIRECT LLD VERSION ---"

"$RUNNER" "$BOX64" "$LLD" --version 2>&1
DIRECT_LLD_RC=$?

echo "DIRECT_LLD_RC=$DIRECT_LLD_RC"

echo
echo "--- 9. LLD OBJECT-ONLY LINK ---"

"$RUNNER" "$BOX64" "$LLD" \
    -flavor gnu \
    -m aarch64linux \
    -pie \
    -o "$TESTDIR/link_object_only" \
    "$TESTDIR/test.o" \
    2>&1

OBJECT_LINK_RC=$?

echo "OBJECT_LINK_RC=$OBJECT_LINK_RC"

if [ -f "$TESTDIR/link_object_only" ]; then
    echo "OBJECT_LINK_OUTPUT=YES"
    file "$TESTDIR/link_object_only"
else
    echo "OBJECT_LINK_OUTPUT=NO"
fi

echo
echo "--- 10. LLD + BUILTINS ONLY ---"

"$RUNNER" "$BOX64" "$LLD" \
    -flavor gnu \
    -m aarch64linux \
    -pie \
    -o "$TESTDIR/link_builtins" \
    "$TESTDIR/test.o" \
    "$BUILTINS" \
    2>&1

BUILTINS_LINK_RC=$?

echo "BUILTINS_LINK_RC=$BUILTINS_LINK_RC"

if [ -f "$TESTDIR/link_builtins" ]; then
    echo "BUILTINS_LINK_OUTPUT=YES"
    file "$TESTDIR/link_builtins"
else
    echo "BUILTINS_LINK_OUTPUT=NO"
fi

echo
echo "--- 11. NDK CRT FILES ---"

CRTBEGIN="$SYSROOT/usr/lib/aarch64-linux-android/21/crtbegin_dynamic.o"
CRTEND="$SYSROOT/usr/lib/aarch64-linux-android/21/crtend_android.o"

echo "CRTBEGIN=$CRTBEGIN"
echo "CRTEND=$CRTEND"

ls -l "$CRTBEGIN" 2>&1
ls -l "$CRTEND" 2>&1

echo
echo "--- 12. NDK LIBRARY DIRECTORY ---"

NDKLIB="$SYSROOT/usr/lib/aarch64-linux-android/21"

echo "NDKLIB=$NDKLIB"

ls -l "$NDKLIB" 2>&1 | head -80

echo
echo "--- 13. LIBC CHECK ---"

for f in \
    "$NDKLIB/libc.so" \
    "$SYSROOT/usr/lib/aarch64-linux-android/libc.so" \
    "$NDKLIB/libdl.so" \
    "$SYSROOT/usr/lib/aarch64-linux-android/libdl.so"
do
    echo
    echo "FILE=$f"

    if [ -e "$f" ]; then
        ls -l "$f"
        file "$f"
    else
        echo "NOT_FOUND"
    fi
done

echo
echo "--- 14. LIBUNWIND CHECK ---"

echo "UNWIND=$UNWIND"

if [ -f "$UNWIND" ]; then
    ls -l "$UNWIND"
    file "$UNWIND"
    ar t "$UNWIND" 2>&1 | head -20
else
    echo "UNWIND_NOT_FOUND"
fi

echo
echo "--- 15. NDK LIBUNWIND SEARCH ---"

find "$X86" \
    -type f \
    \( -name 'libunwind.a' -o -name 'libunwind.so*' \) \
    2>/dev/null | head -50

echo
echo "--- 16. LIBXML X86_64 CHECK ---"

X86LIB="$GLIBC/lib/box64-x86_64-linux-gnu"

echo "X86LIB=$X86LIB"

find "$X86LIB" \
    -maxdepth 1 \
    \( -name 'libxml2.so*' -o -name 'libz.so*' -o -name 'liblzma.so*' \) \
    -print 2>/dev/null

echo
echo "--- 17. HOST LIBXML ---"

for f in \
    "$PREFIX/lib/libxml2.so.16.1.3" \
    "$NDK/lib/libxml2.so.2" \
    "$X86/lib/libxml2.so.2" \
    "$X86/lib64/libxml2.so.2"
do
    echo
    echo "FILE=$f"

    if [ -e "$f" ]; then
        ls -l "$f"
        file "$f"
        readelf -d "$f" 2>/dev/null | grep NEEDED | head -20
    else
        echo "NOT_FOUND"
    fi
done

echo
echo "--- 18. BOX64 LIBRARY SEARCH VARIABLES ---"

env | grep -E \
'^(BOX64|LD_LIBRARY_PATH|BOX64_LD_LIBRARY_PATH|BOX64_PATH|GLIBC|PREFIX)=' \
| sort || true

echo
echo "--- 19. BOX64 SELF-TEST WITH LIBRARY TRACE ---"

BOX64_LOG="$TESTDIR/box64_trace.log"

BOX64_TRACE=1 \
BOX64_TRACE_FILE="$BOX64_LOG" \
"$RUNNER" "$BOX64" "$LLD" --version 2>&1

TRACE_RC=$?

echo "TRACE_RC=$TRACE_RC"

if [ -f "$BOX64_LOG" ]; then
    echo "--- TRACE HEAD ---"
    head -100 "$BOX64_LOG"
else
    echo "TRACE_FILE_NOT_CREATED"
fi

echo
echo "--- 20. CLANG DRIVER VERBOSE LINK ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -v \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/driver_link" \
    2>&1

DRIVER_LINK_RC=$?

echo "DRIVER_LINK_RC=$DRIVER_LINK_RC"

if [ -f "$TESTDIR/driver_link" ]; then
    echo "DRIVER_LINK_OUTPUT=YES"
    file "$TESTDIR/driver_link"
else
    echo "DRIVER_LINK_OUTPUT=NO"
fi

echo
echo "--- 21. CLANG DRIVER WITHOUT UNWIND ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    --sysroot="$SYSROOT" \
    -nostartfiles \
    -nostdlib \
    -Wl,-e,main \
    "$TESTDIR/test.o" \
    -o "$TESTDIR/naked_link" \
    2>&1

NAKED_RC=$?

echo "NAKED_LINK_RC=$NAKED_RC"

if [ -f "$TESTDIR/naked_link" ]; then
    echo "NAKED_LINK_OUTPUT=YES"
    file "$TESTDIR/naked_link"
else
    echo "NAKED_LINK_OUTPUT=NO"
fi

echo
echo "--- 22. FINAL FILE INVENTORY ---"

find "$TESTDIR" \
    -maxdepth 1 \
    -type f \
    -printf '%f\n' \
    2>/dev/null | sort

echo
echo "--- 23. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "BOX64_RC=0"
echo "CLANG_VERSION_RC=$CLANG_VERSION_RC"
echo "LLD_VERSION_RC=$LLD_VERSION_RC"
echo "COMPILE_RC=$COMPILE_RC"
echo "DIRECT_LLD_RC=$DIRECT_LLD_RC"
echo "OBJECT_LINK_RC=$OBJECT_LINK_RC"
echo "BUILTINS_LINK_RC=$BUILTINS_LINK_RC"
echo "DRIVER_LINK_RC=$DRIVER_LINK_RC"
echo "NAKED_LINK_RC=$NAKED_RC"
echo "TRACE_RC=$TRACE_RC"

echo
echo "=================================================="
echo " PHASE 180 COMPLETE"
echo "=================================================="

echo "TESTDIR=$TESTDIR"
echo "RESULT_FILE=$RESULT"

echo "=================================================="

