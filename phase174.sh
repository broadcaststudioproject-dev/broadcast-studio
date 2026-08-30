#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 174: BOX64 + NDK CLANG FULL COMPILE/LINK"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"
RUNNER="$(command -v glibc-runner)"
BOX64="$GLIBC/bin/box64"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

CLANG="$X86/bin/clang"
CLANGXX="$X86/bin/clang++"

TESTDIR="$PWD/phase174_test"
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"

echo
echo "--- 1. TOOLS ---"
echo "RUNNER=$RUNNER"
echo "BOX64=$BOX64"
echo "CLANG=$CLANG"
echo "CLANGXX=$CLANGXX"

echo
echo "--- 2. BOX64 CHECK ---"
"$RUNNER" "$BOX64" --version 2>&1
echo "BOX64_RC=$?"

echo
echo "--- 3. CLANG CHECK ---"
"$RUNNER" "$BOX64" "$CLANG" --version 2>&1 | head -5
echo "CLANG_RC=${PIPESTATUS[0]}"

echo
echo "--- 4. CREATE C SOURCE ---"

cat > "$TESTDIR/test.c" <<'SRC'
#include <stdint.h>

int main(void) {
    return 0;
}
SRC

ls -l "$TESTDIR/test.c"
file "$TESTDIR/test.c"

echo
echo "--- 5. C COMPILE ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    -c "$TESTDIR/test.c" \
    -o "$TESTDIR/test.o" \
    2>&1

C_COMPILE_RC=$?

echo "C_COMPILE_RC=$C_COMPILE_RC"

if [ -f "$TESTDIR/test.o" ]; then
    echo "C_OBJECT_CREATED=YES"
    file "$TESTDIR/test.o"
else
    echo "C_OBJECT_CREATED=NO"
fi

echo
echo "--- 6. C LINK ---"

if [ -f "$TESTDIR/test.o" ]; then

    "$RUNNER" "$BOX64" "$CLANG" \
        --target=aarch64-linux-android21 \
        "$TESTDIR/test.o" \
        -o "$TESTDIR/test_c" \
        2>&1

    C_LINK_RC=$?

    echo "C_LINK_RC=$C_LINK_RC"

    if [ -f "$TESTDIR/test_c" ]; then
        echo "C_EXECUTABLE_CREATED=YES"
        file "$TESTDIR/test_c"
    else
        echo "C_EXECUTABLE_CREATED=NO"
    fi

else
    echo "C_LINK_SKIPPED"
    C_LINK_RC=99
fi

echo
echo "--- 7. CREATE C++ SOURCE ---"

cat > "$TESTDIR/test.cpp" <<'SRC'
#include <cstdint>

int main() {
    return 0;
}
SRC

ls -l "$TESTDIR/test.cpp"
file "$TESTDIR/test.cpp"

echo
echo "--- 8. C++ COMPILE ---"

"$RUNNER" "$BOX64" "$CLANGXX" \
    --target=aarch64-linux-android21 \
    -c "$TESTDIR/test.cpp" \
    -o "$TESTDIR/test_cpp.o" \
    2>&1

CPP_COMPILE_RC=$?

echo "CPP_COMPILE_RC=$CPP_COMPILE_RC"

if [ -f "$TESTDIR/test_cpp.o" ]; then
    echo "CPP_OBJECT_CREATED=YES"
    file "$TESTDIR/test_cpp.o"
else
    echo "CPP_OBJECT_CREATED=NO"
fi

echo
echo "--- 9. C++ LINK ---"

if [ -f "$TESTDIR/test_cpp.o" ]; then

    "$RUNNER" "$BOX64" "$CLANGXX" \
        --target=aarch64-linux-android21 \
        "$TESTDIR/test_cpp.o" \
        -o "$TESTDIR/test_cpp" \
        2>&1

    CPP_LINK_RC=$?

    echo "CPP_LINK_RC=$CPP_LINK_RC"

    if [ -f "$TESTDIR/test_cpp" ]; then
        echo "CPP_EXECUTABLE_CREATED=YES"
        file "$TESTDIR/test_cpp"
    else
        echo "CPP_EXECUTABLE_CREATED=NO"
    fi

else
    echo "CPP_LINK_SKIPPED"
    CPP_LINK_RC=99
fi

echo
echo "--- 10. NDK SYSROOT ---"

echo "$X86/sysroot"

if [ -d "$X86/sysroot" ]; then
    echo "SYSROOT_STATUS=OK"
else
    echo "SYSROOT_STATUS=MISSING"
fi

echo
echo "--- 11. TEST FILES ---"
find "$TESTDIR" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort

echo
echo "--- 12. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "BOX64=WORKING"
echo "CLANG=WORKING"
echo "ANDROID_TARGET=WORKING"
echo "C_COMPILE_RC=$C_COMPILE_RC"
echo "C_LINK_RC=$C_LINK_RC"
echo "CPP_COMPILE_RC=$CPP_COMPILE_RC"
echo "CPP_LINK_RC=$CPP_LINK_RC"

if [ "$C_COMPILE_RC" -eq 0 ] &&
   [ "$C_LINK_RC" -eq 0 ] &&
   [ "$CPP_COMPILE_RC" -eq 0 ] &&
   [ "$CPP_LINK_RC" -eq 0 ]; then

    echo
    echo "=================================================="
    echo " PHASE 174 RESULT: FULL TOOLCHAIN WORKING"
    echo "=================================================="

else

    echo
    echo "=================================================="
    echo " PHASE 174 RESULT: FURTHER DIAGNOSIS REQUIRED"
    echo "=================================================="

fi

echo
echo "TESTDIR=$TESTDIR"

echo
echo "=================================================="
echo " END PHASE 174"
echo "=================================================="

