#!/data/data/com.termux/files/usr/bin/bash

set +e

ROOT="$HOME/pocket_pcr_studio"
NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt"
HOSTPRE="$PRE/linux-x86_64"

echo "=================================================="
echo " PHASE 201: NDK HOST PATH RESOLUTION TEST"
echo "=================================================="

echo
echo "--- 1. NDK ---"
echo "NDK=$NDK"
test -d "$NDK" && echo "NDK_DIR=YES" || echo "NDK_DIR=NO"

echo
echo "--- 2. PREBUILT ---"
echo "PRE=$PRE"
ls -la "$PRE" 2>/dev/null

echo
echo "--- 3. EXPECTED HOST DIRECTORY ---"
echo "HOSTPRE=$HOSTPRE"
test -d "$HOSTPRE" && echo "HOSTPRE=YES" || echo "HOSTPRE=NO"

echo
echo "--- 4. CLANG ---"
echo "CLANG=$HOSTPRE/bin/clang"
test -x "$HOSTPRE/bin/clang" && echo "CLANG=YES" || echo "CLANG=NO"

echo
echo "--- 5. LLD ---"
echo "LLD=$HOSTPRE/bin/ld.lld"
test -x "$HOSTPRE/bin/ld.lld" && echo "LLD=YES" || echo "LLD=NO"

echo
echo "--- 6. WRONG PATH FROM FLUTTER ERROR ---"
BAD="$PRE/bin/clang"
echo "BAD=$BAD"
test -e "$BAD" && echo "BAD_PATH_EXISTS=YES" || echo "BAD_PATH_EXISTS=NO"

echo
echo "--- 7. NDK TOOLCHAIN ---"
TOOLCHAIN="$NDK/build/cmake/android.toolchain.cmake"
test -f "$TOOLCHAIN" && echo "TOOLCHAIN_FILE=YES" || echo "TOOLCHAIN_FILE=NO"

echo
echo "--- 8. TOOLCHAIN HOST REFERENCES ---"
grep -nE 'prebuilt|CMAKE_C_COMPILER|ANDROID_TOOLCHAIN' \
"$TOOLCHAIN" 2>/dev/null | head -40

echo
echo "--- 9. PHASE 195 WORKING PATH ---"
if [ -x "$ROOT/phase195_test/ld-wrapper" ]; then
    cat "$ROOT/phase195_test/ld-wrapper"
else
    echo "WRAPPER=NOT_FOUND"
fi

echo
echo "--- 10. FINAL STATUS ---"
echo "HOST=$(uname -m)"

if [ -x "$HOSTPRE/bin/clang" ] &&
   [ -x "$HOSTPRE/bin/ld.lld" ] &&
   [ -f "$TOOLCHAIN" ]; then
    echo "NDK_HOST_TOOLCHAIN=AVAILABLE"
else
    echo "NDK_HOST_TOOLCHAIN=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 201 COMPLETE"
echo "=================================================="
