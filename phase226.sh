#!/data/data/com.termux/files/usr/bin/bash

NDK="$HOME/../usr/opt/android-sdk/ndk/28.2.13676358"
SYSROOT="$NDK/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
LIB="$SYSROOT/usr/lib/aarch64-linux-android"

echo "=================================================="
echo "PHASE 226: ANDROID AARCH64 UNWIND PROVIDER"
echo "=================================================="

echo
echo "--- 1. ANDROID AARCH64 LIBRARY ROOT ---"
echo "$LIB"

echo
echo "--- 2. SEARCH _Unwind_Resume ---"

find "$LIB" -type f \
  \( -name '*.a' -o -name '*.so' \) \
  -print0 2>/dev/null |
while IFS= read -r -d '' f; do
    if llvm-nm -A "$f" 2>/dev/null |
       grep -qE '(^| )(_Unwind_Resume|__gxx_personality_v0)( |$)'; then
        echo "$f"
    fi
done

echo
echo "--- 3. ANDROID AARCH64 RUNTIME FILES ---"

find "$LIB" -maxdepth 2 -type f \
  \( -name 'libunwind*' -o -name 'libc++abi*' -o -name 'libc++*' \) \
  -print 2>/dev/null

echo
echo "--- 4. DIRECT DRIVER WITHOUT UNWINDLIB NONE ---"

cat > /tmp/phase226.cpp <<'CPP'
#include <iostream>
int main() {
    std::cout << "PHASE226" << std::endl;
    return 0;
}
CPP

clang++ \
  --target=aarch64-linux-android21 \
  --sysroot="$SYSROOT" \
  -stdlib=libc++ \
  /tmp/phase226.cpp \
  -o /tmp/phase226_test \
  2>&1 | tail -10

RC=$?

echo
echo "DIRECT_LINK_RC=$RC"

echo
echo "--- 5. DRIVER DEFAULT LINK RUNTIME ---"

clang++ \
  --target=aarch64-linux-android21 \
  --sysroot="$SYSROOT" \
  -stdlib=libc++ \
  -### \
  /tmp/phase226.cpp \
  -o /tmp/phase226_test \
  2>&1 |
grep -oE -- '-l:libunwind\.a|-lc\+\+_shared|-lc\+\+abi|-lc |-lunwind' |
sort -u

echo
echo "=================================================="
echo "PHASE 226 COMPLETE"
echo "=================================================="
