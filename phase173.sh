#!/data/data/com.termux/files/usr/bin/bash

echo "=================================================="
echo " PHASE 173: GLIBC-RUNNER + BOX64 + NDK CLANG"
echo "=================================================="

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC="$PREFIX/glibc"

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
X86="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

CLANG="$X86/bin/clang"
CLANGXX="$X86/bin/clang++"

RUNNER="$(command -v glibc-runner)"
BOX64="$GLIBC/bin/box64"

echo
echo "--- 1. TOOLS ---"
echo "RUNNER=$RUNNER"
echo "BOX64=$BOX64"
echo "CLANG=$CLANG"
echo "CLANGXX=$CLANGXX"

echo
echo "--- 2. BOX64 VERSION THROUGH RUNNER ---"
"$RUNNER" "$BOX64" --version 2>&1
echo "RC=${PIPESTATUS[0]}"

echo
echo "--- 3. CLANG VERSION THROUGH BOX64 ---"
"$RUNNER" "$BOX64" "$CLANG" --version 2>&1
RC=${PIPESTATUS[0]}
echo "CLANG_RC=$RC"

echo
echo "--- 4. CLANG++ VERSION THROUGH BOX64 ---"
"$RUNNER" "$BOX64" "$CLANGXX" --version 2>&1
RC=${PIPESTATUS[0]}
echo "CLANGXX_RC=$RC"

echo
echo "--- 5. ANDROID TARGET TEST ---"
"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    -v -E /dev/null 2>&1 | head -40

RC=${PIPESTATUS[0]}
echo "TARGET_RC=$RC"

echo
echo "--- 6. SIMPLE C COMPILE ---"

cat > /tmp/pcr_test.c <<'SRC'
int main(void) {
    return 0;
}
SRC

"$RUNNER" "$BOX64" "$CLANG" \
    --target=aarch64-linux-android21 \
    -c /tmp/pcr_test.c \
    -o /tmp/pcr_test.o 2>&1

RC=$?
echo "COMPILE_RC=$RC"

if [ -f /tmp/pcr_test.o ]; then
    echo "OBJECT_CREATED=YES"
    file /tmp/pcr_test.o
else
    echo "OBJECT_CREATED=NO"
fi

echo
echo "--- 7. SIMPLE C++ COMPILE ---"

cat > /tmp/pcr_test.cpp <<'SRC'
int main() {
    return 0;
}
SRC

"$RUNNER" "$BOX64" "$CLANGXX" \
    --target=aarch64-linux-android21 \
    -c /tmp/pcr_test.cpp \
    -o /tmp/pcr_test_cpp.o 2>&1

RC=$?
echo "CPP_COMPILE_RC=$RC"

if [ -f /tmp/pcr_test_cpp.o ]; then
    echo "CPP_OBJECT_CREATED=YES"
    file /tmp/pcr_test_cpp.o
else
    echo "CPP_OBJECT_CREATED=NO"
fi

echo
echo "--- 8. CLANG RESOURCE DIRECTORY ---"

"$RUNNER" "$BOX64" "$CLANG" \
    --print-resource-dir 2>&1

echo
echo "--- 9. NDK SYSROOT ---"

find "$NDK/toolchains/llvm/prebuilt/linux-x86_64" \
    -maxdepth 5 \
    -type d \
    -name 'sysroot' \
    2>/dev/null | head -10

echo
echo "--- 10. FINAL STATUS ---"

echo "HOST=$(uname -m)"
echo "BOX64_STATUS=CHECKED"
echo "CLANG_VERSION_STATUS=$CLANG_RC"
echo "CLANGXX_VERSION_STATUS=$CLANGXX_RC"
echo "TARGET_STATUS=$TARGET_RC"
echo "C_COMPILE_STATUS=$COMPILE_RC"
echo "CPP_COMPILE_STATUS=$CPP_COMPILE_RC"

echo
echo "=================================================="
echo " END PHASE 173"
echo "=================================================="
