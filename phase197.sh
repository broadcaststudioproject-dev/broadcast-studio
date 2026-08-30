#!/data/data/com.termux/files/usr/bin/bash
set +e

echo "=================================================="
echo " PHASE 197: FLUTTER NATIVE BUILD CHAIN TRACE"
echo "=================================================="

ROOT="$HOME/pocket_pcr_studio"
TEST="$ROOT/phase197_test"
mkdir -p "$TEST"

echo
echo "--- 1. PROJECT ---"
echo "ROOT=$ROOT"
test -f "$ROOT/pubspec.yaml" && echo "PUBSPEC=YES" || echo "PUBSPEC=NO"

echo
echo "--- 2. FLUTTER ---"
command -v flutter
flutter --version 2>&1 | head -3

echo
echo "--- 3. ANDROID PROJECT ---"
test -d "$ROOT/android" && echo "ANDROID_DIR=YES" || echo "ANDROID_DIR=NO"
test -f "$ROOT/android/settings.gradle" && echo "SETTINGS_GRADLE=YES"
test -f "$ROOT/android/settings.gradle.kts" && echo "SETTINGS_GRADLE_KTS=YES"
test -f "$ROOT/android/app/build.gradle" && echo "APP_GRADLE=YES"
test -f "$ROOT/android/app/build.gradle.kts" && echo "APP_GRADLE_KTS=YES"

echo
echo "--- 4. NDK ---"
NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
echo "NDK=$NDK"
test -d "$NDK" && echo "NDK_DIR=YES" || echo "NDK_DIR=NO"

echo
echo "--- 5. PHASE 195 WRAPPER ---"
WRAPPER="$ROOT/phase195_test/ld-wrapper"
echo "WRAPPER=$WRAPPER"
test -x "$WRAPPER" && echo "LD_WRAPPER=YES" || echo "LD_WRAPPER=NO"

echo
echo "--- 6. CMAKE FILES ---"
find "$ROOT/android" -type f \
  \( -name "CMakeLists.txt" -o -name "*.cmake" \) \
  2>/dev/null | head -30

echo
echo "--- 7. GRADLE CMAKE REFERENCES ---"
grep -RniE 'externalNativeBuild|cmake|ndkVersion|abiFilters' \
  "$ROOT/android" 2>/dev/null | head -80

echo
echo "--- 8. LINKER REFERENCES ---"
grep -RniE 'fuse-ld|ld-wrapper|CMAKE_EXE_LINKER_FLAGS|CMAKE_(C|CXX)_LINKER' \
  "$ROOT/android" 2>/dev/null | head -80

echo
echo "--- 9. CMAKE CACHE REFERENCES ---"
find "$ROOT" -name CMakeCache.txt -type f 2>/dev/null | head -20

echo
echo "--- 10. GRADLE VERSION ---"
if [ -x "$ROOT/android/gradlew" ]; then
    "$ROOT/android/gradlew" --version 2>&1 | head -20
else
    echo "GRADLEW=NOT_FOUND"
fi

echo
echo "--- 11. FLUTTER DOCTOR ANDROID ---"
flutter doctor -v 2>&1 | grep -E \
'Flutter|Android toolchain|Android SDK|NDK|CMake|Java|Gradle' | head -40

echo
echo "--- 12. FINAL STATUS ---"
echo "HOST=$(uname -m)"
echo "PROJECT=$([ -f "$ROOT/pubspec.yaml" ] && echo YES || echo NO)"
echo "ANDROID=$([ -d "$ROOT/android" ] && echo YES || echo NO)"
echo "NDK=$([ -d "$NDK" ] && echo YES || echo NO)"
echo "LD_WRAPPER=$([ -x "$WRAPPER" ] && echo YES || echo NO)"

echo
echo "=================================================="
echo " PHASE 197 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TEST"
echo "RESULT_FILE=$ROOT/phase197_result.txt"
echo "=================================================="
