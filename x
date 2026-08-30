cd ~/pocket_pcr_studio

cat > phase215_android_link_test.c <<'EOF'
#include <stdio.h>

int main(void) {
    printf("PHASE 215 ANDROID ARM64 LINK TEST\n");
    return 0;
}
EOF

NDK="$PREFIX/opt/android-sdk/ndk/28.2.13676358"
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

CLANG="$PREFIX/bin/clang"
TARGET="aarch64-linux-android21"
SYSROOT="$PRE/sysroot"

echo "=== PHASE 215: DIRECT ANDROID ARM64 LINK TEST ==="
echo
echo "CLANG=$CLANG"
echo "TARGET=$TARGET"
echo "SYSROOT=$SYSROOT"
echo

echo "--- 1. COMPILER ---"
"$CLANG" --version

echo
echo "--- 2. TARGET CHECK ---"
"$CLANG" \
  --target="$TARGET" \
  --sysroot="$SYSROOT" \
  -### \
  -c phase215_android_link_test.c \
  2>&1 | tail -20

echo
echo "--- 3. DIRECT LINK ---"

"$CLANG" \
  --target="$TARGET" \
  --sysroot="$SYSROOT" \
  phase215_android_link_test.c \
  -o phase215_android_link_test \
  2>&1 | tee phase215_link.log

LINK_RC=${PIPESTATUS[0]}

echo
echo "LINK_RC=$LINK_RC"

echo
echo "--- 4. EXECUTABLE ---"

if [ -f phase215_android_link_test ]; then
    file phase215_android_link_test

    echo
    "$PREFIX/bin/llvm-readelf" -h \
      phase215_android_link_test 2>/dev/null | \
      grep -E 'Class:|OS/ABI:|Type:|Machine:|Entry point:'

    echo
    echo "--- NEEDED ---"
    "$PREFIX/bin/llvm-readelf" -d \
      phase215_android_link_test 2>/dev/null | \
      grep NEEDED || true
else
    echo "EXECUTABLE=NOT_CREATED"
fi

echo
echo "--- 5. RESULT ---"

if [ "$LINK_RC" -eq 0 ] && [ -f phase215_android_link_test ]; then
    echo "PHASE215=SUCCESS"
else
    echo "PHASE215=FAILED"
fi
