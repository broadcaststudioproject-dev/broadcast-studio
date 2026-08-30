#!/data/data/com.termux/files/usr/bin/bash

set +e

ROOT="$HOME/pocket_pcr_studio"
TEST="$ROOT/phase198_test"

echo "=================================================="
echo " PHASE 198: FLUTTER ARM64 BUILD TRACE"
echo "=================================================="

mkdir -p "$TEST"

cd "$ROOT" || exit 1

echo
echo "--- 1. ENVIRONMENT ---"
echo "HOST=$(uname -m)"
echo "FLUTTER=$(flutter --version 2>/dev/null | head -1)"
echo "JAVA=$(java -version 2>&1 | head -1)"
echo "GRADLE=$(cd android 2>/dev/null && ./gradlew --version 2>/dev/null | grep '^Gradle ' | head -1)"

echo
echo "--- 2. NDK ---"
NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
echo "NDK=$NDK"
test -d "$NDK" && echo "NDK=YES" || echo "NDK=NO"

echo
echo "--- 3. PROJECT ABI ---"
grep -R "arm64-v8a" android/app/build.gradle.kts android 2>/dev/null | head -10

echo
echo "--- 4. FLUTTER BUILD ---"
rm -f "$TEST/build.log"

flutter build apk --debug \
  --target-platform android-arm64 \
  -v 2>&1 | tee "$TEST/build.log"

BUILD_RC=${PIPESTATUS[0]}

echo
echo "--- 5. LINKER / LIBUNWIND ERRORS ---"
grep -Ei "libunwind|ld.lld|linker command failed|fuse-ld|BOX64|buffer overflow" \
  "$TEST/build.log" | tail -80

echo
echo "--- 6. APK ---"
APK=$(find "$ROOT/build" -type f -name "*.apk" 2>/dev/null | head -1)

if [ -n "$APK" ]; then
    echo "APK=CREATED"
    echo "$APK"
else
    echo "APK=NOT_CREATED"
fi

echo
echo "--- 7. FINAL STATUS ---"
echo "HOST=$(uname -m)"
echo "BUILD_RC=$BUILD_RC"

if [ "$BUILD_RC" -eq 0 ] && [ -n "$APK" ]; then
    echo "FLUTTER_ARM64_BUILD=SUCCESS"
else
    echo "FLUTTER_ARM64_BUILD=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 198 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TEST"
echo "RESULT_FILE=$TEST/phase198_result.txt"
echo "=================================================="

{
    echo "BUILD_RC=$BUILD_RC"
    echo "APK=${APK:-NOT_CREATED}"
} > "$TEST/phase198_result.txt"
