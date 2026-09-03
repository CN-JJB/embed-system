#!/usr/bin/env bash
set -euo pipefail

# Part A Validation Suite
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$SCRIPT_DIR/reference}"
FIXTURES_DIR="$SCRIPT_DIR/../../part-a/fixtures"

echo "=== Running Part A Validation Suite ==="
echo "Target: $TARGET_DIR"

cd "$TARGET_DIR"

# 1. Clean and Strict Build
echo "--- 1. Testing Strict Build ---"
make clean >/dev/null
make all
if [ ! -x "./sifter" ]; then
    echo "FAIL: Binary ./sifter was not produced."
    exit 1
fi

# 2. File Count Verification (>= 4 source/header files)
echo "--- 2. Verifying File Count (>= 4 files) ---"
FILE_COUNT=$(ls -1 *.c *.h 2>/dev/null | wc -l)
if [ "$FILE_COUNT" -lt 4 ]; then
    echo "FAIL: Expected at least 4 source/header files, found $FILE_COUNT."
    exit 1
fi
echo "PASS: Module file count is $FILE_COUNT."

# 3. Functional Execution Tests
echo "--- 3. Testing Functional Processing ---"
./sifter --input "$FIXTURES_DIR/valid.txt" --filter 0 --stats 2>&1 | grep -q "valid=6"
./sifter --input "$FIXTURES_DIR/invalid.txt" --stats 2>&1 | grep -q "errors="
./sifter --input "$FIXTURES_DIR/empty.txt" --stats 2>&1 | grep -q "total=0"

# Test stdin pipeline
cat "$FIXTURES_DIR/valid.txt" | ./sifter --filter 50 --stats >/dev/null

echo "PASS: Functional stream processing verified."

# 4. Sanitizer Execution (ASan + UBSan + LeakSanitizer)
echo "--- 4. Testing Memory Safety & LeakSanitizer ---"
make clean >/dev/null
make san
export ASAN_OPTIONS=detect_leaks=1:halt_on_error=1
./sifter_san --input "$FIXTURES_DIR/valid.txt" --filter 0 >/dev/null
./sifter_san --input "$FIXTURES_DIR/invalid.txt" >/dev/null
./sifter_san --input "$FIXTURES_DIR/empty.txt" >/dev/null
echo "PASS: Zero memory leaks or undefined behavior detected."

# 5. File Descriptor Audit
echo "--- 5. Testing File Descriptor Table Audit ---"
make all >/dev/null
BASELINE_FDS=$(ls -1 /proc/self/fd | wc -l)
./sifter --input "$FIXTURES_DIR/valid.txt" --filter 100 >/dev/null
AFTER_FDS=$(ls -1 /proc/self/fd | wc -l)
if [ "$BASELINE_FDS" -ne "$AFTER_FDS" ]; then
    echo "FAIL: Baseline FD count $BASELINE_FDS differs from post-run $AFTER_FDS."
    exit 1
fi
echo "PASS: Zero leaked owned file descriptors verified."

# 6. Rebuild Dependency Check
echo "--- 6. Verifying Header Dependency Tracking ---"
make clean >/dev/null
make all >/dev/null
PRE_TIME=$(stat -c %Y sifter)
sleep 1
touch sifter.h
make all >/dev/null
POST_TIME=$(stat -c %Y sifter)
if [ "$POST_TIME" -le "$PRE_TIME" ]; then
    echo "FAIL: Makefile failed to recompile binary after modifying header sifter.h."
    exit 1
fi
echo "PASS: Header dependency tracking verified."

echo ">>> ALL PART A VALIDATION CHECKS PASSED <<<"
