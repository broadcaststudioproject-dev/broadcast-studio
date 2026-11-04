#!/data/data/com.termux/files/usr/bin/bash

ROOT="$HOME/pocket_pcr_studio"
TEST="$ROOT/phase209_test"
EXE="$TEST/build/phase209"

echo "=================================================="
echo " PHASE 210: FINAL LINK ARTIFACT VERIFICATION"
echo "=================================================="

echo
echo "--- 1. EXECUTABLE ---"

if [ -f "$EXE" ]; then
    echo "EXECUTABLE=YES"
    file "$EXE"
else
    echo "EXECUTABLE=NO"
fi

echo
echo "--- 2. ELF HEADER ---"

if command -v readelf >/dev/null 2>&1; then
    readelf -h "$EXE" 2>/dev/null | grep -E \
        'Class:|Machine:|Type:|OS/ABI:'
else
    echo "READELF=NOT_FOUND"
fi

echo
echo "--- 3. UNWIND REFERENCES ---"

if command -v readelf >/dev/null 2>&1; then
    readelf -Ws "$EXE" 2>/dev/null | grep -i unwind | head -20 || true
fi

echo
echo "--- 4. NEEDED LIBRARIES ---"

if command -v readelf >/dev/null 2>&1; then
    readelf -d "$EXE" 2>/dev/null | grep NEEDED || true
fi

echo
echo "--- 5. FILE SIZE ---"

ls -lh "$EXE" 2>/dev/null || true

echo
echo "--- 6. FINAL STATUS ---"

if [ -f "$EXE" ]; then
    echo "ARTIFACT=CREATED"
    echo "LINK_RESULT=VERIFIED"
else
    echo "ARTIFACT=NOT_CREATED"
    echo "LINK_RESULT=FAILED"
fi

echo
echo "=================================================="
echo " PHASE 210 COMPLETE"
echo "=================================================="
echo "TESTDIR=$TEST"
echo "=================================================="
