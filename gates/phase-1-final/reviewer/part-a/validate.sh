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
./sifter --input "$FIXTURES_DIR/valid.txt" --filter 0 --stats 2>&1 | grep "valid=6" >/dev/null
./sifter --input "$FIXTURES_DIR/invalid.txt" --stats 2>&1 | grep "errors=" >/dev/null
./sifter --input "$FIXTURES_DIR/empty.txt" --stats 2>&1 | grep "total=0" >/dev/null

# Test stdin pipeline
cat "$FIXTURES_DIR/valid.txt" | ./sifter --filter 50 --stats >/dev/null
echo "PASS: Functional stream processing verified."

# 4. CLI Option Range Validation
echo "--- 4. Testing CLI Filter Range Boundaries ---"
set +e
./sifter --filter 2147483648 >/dev/null 2>&1
OVERFLOW_STATUS=$?
./sifter --filter -2147483649 >/dev/null 2>&1
UNDERFLOW_STATUS=$?
set -e
if [ "$OVERFLOW_STATUS" -eq 0 ] || [ "$UNDERFLOW_STATUS" -eq 0 ]; then
    echo "FAIL: CLI permitted out-of-range filter threshold."
    exit 1
fi
echo "PASS: CLI rejected out-of-range filter thresholds."

# 5. Comprehensive Parser & Grammar Boundaries
echo "--- 5. Testing Parser Grammar & Exact Length Boundaries ---"
gcc -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -I"$TARGET_DIR" \
    "$SCRIPT_DIR/test_boundaries.c" "$TARGET_DIR/parser.c" -o "$SCRIPT_DIR/run_boundaries"
"$SCRIPT_DIR/run_boundaries" >/dev/null
rm -f "$SCRIPT_DIR/run_boundaries"
echo "PASS: All numeric, overflow, and exact 128/129-byte boundaries verified."

# 6. Callback & Context Decoupling Test
echo "--- 6. Testing Callback & Context Decoupling ---"
gcc -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -I"$TARGET_DIR" \
    "$SCRIPT_DIR/test_callback.c" "$TARGET_DIR/sifter.c" "$TARGET_DIR/parser.c" -o "$SCRIPT_DIR/run_callback"
"$SCRIPT_DIR/run_callback" "$FIXTURES_DIR/valid.txt" >/dev/null
rm -f "$SCRIPT_DIR/run_callback"
echo "PASS: Custom caller callback and void *ctx verified."

# 7. In-Process Descriptor Lifecycle Audit
echo "--- 7. Testing In-Process FD Ownership & Lifecycle ---"
gcc -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -I"$TARGET_DIR" \
    "$SCRIPT_DIR/test_lifecycle.c" "$TARGET_DIR/sifter.c" "$TARGET_DIR/parser.c" -o "$SCRIPT_DIR/run_lifecycle"
"$SCRIPT_DIR/run_lifecycle" "$FIXTURES_DIR/valid.txt" >/dev/null
rm -f "$SCRIPT_DIR/run_lifecycle"
echo "PASS: In-process descriptor audit confirmed zero leaked descriptors."

# 8. Sanitizer Execution (ASan + UBSan + LeakSanitizer)
echo "--- 8. Testing Memory Safety & LeakSanitizer ---"
make clean >/dev/null
make san
export ASAN_OPTIONS=detect_leaks=1:halt_on_error=1
./sifter_san --input "$FIXTURES_DIR/valid.txt" --filter 0 >/dev/null
./sifter_san --input "$FIXTURES_DIR/invalid.txt" >/dev/null
./sifter_san --input "$FIXTURES_DIR/empty.txt" >/dev/null
echo "PASS: Zero memory leaks or undefined behavior detected."

# 9. Rebuild Dependency Check
echo "--- 9. Verifying Header Dependency Tracking ---"
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
