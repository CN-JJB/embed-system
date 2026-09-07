#!/usr/bin/env bash
# ==============================================================================
# test_reviewer_negative_controls.sh: Reviewer Negative Controls Suite
# Mandated by Issue #25 & Leader Rework Round 2.
# Tests that reviewer/verify_isolation.py and reviewer/regression_oracle.py
# strictly catch secret leaks, reviewer links, and invalid reference fixes.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=============================================================================="
echo "Running Phase 2 Gate Reviewer-Isolated Negative Controls"
echo "=============================================================================="

NC_PASSED=0
NC_TOTAL=10

TEMP_TEST_DIR=$(mktemp -d /tmp/p2_reviewer_nc_XXXXXX)
trap 'rm -rf "$TEMP_TEST_DIR"' EXIT

# Copy the gate package into a temporary test environment for isolation tests
cp -r "$GATE_DIR" "$TEMP_TEST_DIR/phase-2-final"
NC_GATE_DIR="$TEMP_TEST_DIR/phase-2-final"

assert_reviewer_mutation_fails() {
    local nc_id="$1"
    local desc="$2"
    local command_to_run="$3"

    echo "------------------------------------------------------------"
    echo "Running Reviewer Negative Control $nc_id: $desc"
    
    if eval "$command_to_run" > /dev/null 2>&1; then
        echo "FAIL: Reviewer Negative Control $nc_id unexpectedly PASSED!"
        exit 1
    else
        echo "PASS: Reviewer Negative Control $nc_id was correctly REJECTED."
        NC_PASSED=$((NC_PASSED + 1))
    fi
}

# ------------------------------------------------------------------------------
# RNC 1: Seed A secret injected into learner README
# ------------------------------------------------------------------------------
echo "Note: avoid empty data copy in startup relocation" >> "$NC_GATE_DIR/part-a/README.md"
assert_reviewer_mutation_fails "RNC-1" "Learner README contains Part A secret (empty data copy)" "python3 '$NC_GATE_DIR/reviewer/verify_isolation.py'"
cp "$GATE_DIR/part-a/README.md" "$NC_GATE_DIR/part-a/README.md"

# ------------------------------------------------------------------------------
# RNC 2: Seed B secret injected into learner C source comment
# ------------------------------------------------------------------------------
echo "/* Note: missing DMA_CCR_MINC causes buffer stagnation */" >> "$NC_GATE_DIR/part-b/src/dma.c"
assert_reviewer_mutation_fails "RNC-2" "Learner C source contains Part B secret (missing DMA_CCR_MINC)" "python3 '$NC_GATE_DIR/reviewer/verify_isolation.py'"
cp "$GATE_DIR/part-b/src/dma.c" "$NC_GATE_DIR/part-b/src/dma.c"

# ------------------------------------------------------------------------------
# RNC 3: Seed C secret injected into learner priority checker
# ------------------------------------------------------------------------------
echo 'print("priority byte 0x30 is higher urgency")' >> "$NC_GATE_DIR/part-c/scripts/check_priority.py"
assert_reviewer_mutation_fails "RNC-3" "Learner checker contains Part C secret (priority byte 0x30)" "python3 '$NC_GATE_DIR/reviewer/verify_isolation.py'"
cp "$GATE_DIR/part-c/scripts/check_priority.py" "$NC_GATE_DIR/part-c/scripts/check_priority.py"

# ------------------------------------------------------------------------------
# RNC 4: Seed D secret injected into learner concurrency checker
# ------------------------------------------------------------------------------
echo 'print("fails to release xSensorBusLock")' >> "$NC_GATE_DIR/part-d/scripts/check_concurrency.py"
assert_reviewer_mutation_fails "RNC-4" "Learner checker contains Part D secret (fails to release xSensorBusLock)" "python3 '$NC_GATE_DIR/reviewer/verify_isolation.py'"
cp "$GATE_DIR/part-d/scripts/check_concurrency.py" "$NC_GATE_DIR/part-d/scripts/check_concurrency.py"

# ------------------------------------------------------------------------------
# RNC 5: Prohibited reviewer filename in top-level README
# ------------------------------------------------------------------------------
echo "Reference: see gate_solution.md" >> "$NC_GATE_DIR/README.md"
assert_reviewer_mutation_fails "RNC-5" "Top-level README references prohibited reviewer file (gate_solution.md)" "python3 '$NC_GATE_DIR/reviewer/verify_isolation.py'"
cp "$GATE_DIR/README.md" "$NC_GATE_DIR/README.md"

# ------------------------------------------------------------------------------
# RNC 6: Generic leak marker injected into learner README
# ------------------------------------------------------------------------------
echo "Root Cause: defect identified during inspection" >> "$NC_GATE_DIR/part-b/README.md"
assert_reviewer_mutation_fails "RNC-6" "Learner README contains generic leak marker (Root Cause:)" "python3 '$NC_GATE_DIR/reviewer/verify_isolation.py'"
cp "$GATE_DIR/part-b/README.md" "$NC_GATE_DIR/part-b/README.md"

# ------------------------------------------------------------------------------
# Build seeded binaries in repository tree for oracle tests
# ------------------------------------------------------------------------------
make -C "$GATE_DIR/part-a" clean all > /dev/null 2>&1
make -C "$GATE_DIR/part-b" clean all > /dev/null 2>&1
make -C "$GATE_DIR/part-c" clean all > /dev/null 2>&1

# ------------------------------------------------------------------------------
# RNC 7: Reviewer Oracle Part A rejects seeded build as reference pass
# ------------------------------------------------------------------------------
assert_reviewer_mutation_fails "RNC-7" "Reviewer Oracle Part A rejects seeded build as reference pass" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-a '$GATE_DIR/part-a/build/firmware.elf' | grep -q '\[REFERENCE_PASS\]'"

# ------------------------------------------------------------------------------
# RNC 8: Reviewer Oracle Part B rejects seeded build as reference pass
# ------------------------------------------------------------------------------
assert_reviewer_mutation_fails "RNC-8" "Reviewer Oracle Part B rejects seeded build as reference pass" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-b '$GATE_DIR/part-b/build/firmware.elf' | grep -q '\[REFERENCE_PASS\]'"

# ------------------------------------------------------------------------------
# RNC 9: Reviewer Oracle Part C rejects seeded build as reference pass
# ------------------------------------------------------------------------------
assert_reviewer_mutation_fails "RNC-9" "Reviewer Oracle Part C rejects seeded build as reference pass" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-c '$GATE_DIR/part-c/build/firmware.elf' | grep -q '\[REFERENCE_PASS\]'"

# ------------------------------------------------------------------------------
# RNC 10: Reviewer Oracle Part D rejects seeded source as reference pass
# ------------------------------------------------------------------------------
assert_reviewer_mutation_fails "RNC-10" "Reviewer Oracle Part D rejects seeded source as reference pass" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-d '$GATE_DIR/part-d/src/node_app.c' | grep -q '\[REFERENCE_PASS\]'"

echo "=============================================================================="
echo ">>> ALL $NC_PASSED / $NC_TOTAL REVIEWER NEGATIVE CONTROLS SUCCESSFULLY REJECTED <<<"
echo "=============================================================================="
