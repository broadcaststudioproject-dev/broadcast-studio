#!/data/data/com.termux/files/usr/bin/bash
set +e

echo "=================================================="
echo " PHASE 196: REAL PROJECT CMAKE INTEGRATION CHECK"
echo "=================================================="

ROOT="$HOME/pocket_pcr_studio"
T="$ROOT/phase196_test"

rm -rf "$T"
mkdir -p "$T"

echo
echo "--- 1. PROJECT ---"
echo "ROOT=$ROOT"

echo
echo "--- 2. ANDROID ---"

if [ -d "$ROOT/android" ]; then
    echo "ANDROID_DIR=YES"
else
    echo "ANDROID_DIR=NO"
fi

if [ -f "$ROOT/android/CMakeLists.txt" ]; then
    echo "ANDROID_CMAKE=YES"
else
    echo "ANDROID_CMAKE=NO"
fi

echo
echo "--- 3. NATIVE CMAKE FILES ---"

find "$ROOT/android" \
    -name 'CMakeLists.txt' \
    -o -name '*.cmake' \
    2>/dev/null | head -30

echo
echo "--- 4. TOOLCHAIN FILES ---"

find "$ROOT/android" \
    -iname '*toolchain*' \
    2>/dev/null | head -20

echo
echo "--- 5. NDK ---"

NDK="$ROOT/../usr/opt/android-sdk/ndk/28.2.13676358"

if [ -d "$NDK" ]; then
    echo "NDK=YES"
else
    echo "NDK=NO"
fi

echo "NDK=$NDK"

echo
echo "--- 6. NATIVE CLANG ---"

clang --version | head -1

echo
echo "--- 7. NDK LLD ---"

LLD="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/ld.lld"

if [ -x "$LLD" ]; then
    echo "LLD=YES"
    "$ROOT/phase195_test/ld-wrapper" --version 2>&1 | head -2
else
    echo "LLD=NO"
fi

echo
echo "--- 8. PHASE 195 TOOLCHAIN ---"

if [ -f "$ROOT/phase195_test/android-termux-toolchain.cmake" ]; then
    echo "TOOLCHAIN=YES"
else
    echo "TOOLCHAIN=NO"
fi

if [ -x "$ROOT/phase195_test/ld-wrapper" ]; then
    echo "LD_WRAPPER=YES"
else
    echo "LD_WRAPPER=NO"
fi

echo
echo "--- 9. FLUTTER PROJECT ---"

if [ -f "$ROOT/pubspec.yaml" ]; then
    echo "FLUTTER_PROJECT=YES"
else
    echo "FLUTTER_PROJECT=NO"
fi

if command -v flutter >/dev/null 2>&1; then
    echo "FLUTTER=$(flutter --version 2>/dev/null | head -1)"
else
    echo "FLUTTER=NOT_FOUND"
fi

echo
echo "--- 10. CMAKE ---"

if command -v cmake >/dev/null 2>&1; then
    echo "CMAKE=$(cmake --version | head -1)"
else
    echo "CMAKE=NOT_FOUND"
fi

echo
echo "--- 11. FINAL STATUS ---"

echo "HOST=$(uname -m)"

if [ -f "$ROOT/pubspec.yaml" ] &&
   [ -d "$ROOT/android" ] &&
   [ -f "$ROOT/phase195_test/android-termux-toolchain.cmake" ] &&
   [ -x "$ROOT/phase195_test/ld-wrapper" ]; then
    echo "PROJECT_INTEGRATION_READY=YES"
else
    echo "PROJECT_INTEGRATION_READY=NO"
fi

echo
echo "=================================================="
echo " PHASE 196 COMPLETE"
echo "=================================================="
echo "TESTDIR=$T"
echo "RESULT_FILE=$ROOT/phase196_result.txt"
echo "=================================================="
