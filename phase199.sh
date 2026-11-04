#!/data/data/com.termux/files/usr/bin/bash

set -o pipefail

ROOT="$HOME/pocket_pcr_studio"
TESTDIR="$ROOT/phase199_test"
LOG="$TESTDIR/build.log"

mkdir -p "$TESTDIR"
cd "$ROOT" || exit 1

echo "=================================================="
echo " PHASE 199: FLUTTER ARM64 LINKER ERROR ISOLATION"
echo "=================================================="

echo
echo "--- 1. PROJECT ---"
pwd
echo "FLUTTER_PROJECT=$(test -f pubspec.yaml && echo YES || echo NO)"

echo
echo "--- 2. FLUTTER ---"
flutter --version 2>&1 | head -5

echo
echo "--- 3. CLEAN ---"
flutter clean > "$TESTDIR/clean.log" 2>&1
echo "CLEAN_RC=$?"

echo
echo "--- 4. PUB GET ---"
flutter pub get > "$TESTDIR/pub_get.log" 2>&1
echo "PUB_GET_RC=$?"

echo
echo "--- 5. ARM64 BUILD ---"
flutter build apk --debug --target-platform android-arm64 \
  2>&1 | tee "$LOG"

BUILD_RC=${PIPESTATUS[0]}

echo
echo "--- 6. LINKER / LIBUNWIND ERRORS ---"
grep -Ei \
'libunwind|ld\.lld|linker command failed|unable to find library|undefined reference|cannot find|clang: error|CMake Error|ninja: error|FAILED' \
"$LOG" | tail -80 || true

echo
echo "--- 7. APK ---"
APK=$(find "$ROOT/build/app/outputs/flutter-apk" \
  -name '*.apk' -type f 2>/dev/null | head -1)

if [ -n "$APK" ]; then
    echo "APK=CREATED"
    echo "$APK"
else
    echo "APK=NOT_CREATED"
fi

echo
echo "--- 8. FINAL STATUS ---"
echo "HOST=$(uname -m)"
echo "BUILD_RC=$BUILD_RC"

if [ -n "$APK" ]; then
    echo "FLUTTER_ARM64_BUILD=SUCCESS"
else
    echo "FLUTTER_ARM64_BUILD=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 199 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TESTDIR"
echo "LOG=$LOG"
echo "=================================================="
