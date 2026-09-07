#!/usr/bin/env bash
# ==============================================================================
# test_negative_controls.sh: Generic Semantic Negative Controls for Gate Validator
# Mandated by Issue #25 & Leader Rework Round 2.
# Tests that verify_gate.sh strictly rejects package mutations, formatting decoys,
# and generic leak markers using fictitious tokens without revealing actual seeds.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=============================================================================="
echo "Running Phase 2 Gate Validator Generic Negative Controls"
echo "=============================================================================="

NC_PASSED=0
NC_TOTAL=10

TEMP_TEST_DIR=$(mktemp -d /tmp/p2_gate_nc_XXXXXX)
trap 'rm -rf "$TEMP_TEST_DIR"' EXIT

# Copy the gate package into a temporary test environment
cp -r "$GATE_DIR" "$TEMP_TEST_DIR/phase-2-final"
NC_GATE_DIR="$TEMP_TEST_DIR/phase-2-final"

assert_mutation_fails() {
    local nc_id="$1"
    local desc="$2"
    local command_to_run="$3"

    echo "------------------------------------------------------------"
    echo "Running Negative Control $nc_id: $desc"
    
    if eval "$command_to_run" > /dev/null 2>&1; then
        echo "FAIL: Negative Control $nc_id unexpectedly PASSED (Validator failed to detect mutation)!"
        exit 1
    else
        echo "PASS: Negative Control $nc_id was correctly REJECTED by validator."
        NC_PASSED=$((NC_PASSED + 1))
    fi
}

# ------------------------------------------------------------------------------
# NC 1: Wrong scoring total (95 instead of 100)
# ------------------------------------------------------------------------------
sed -i 's/| Part A  | Bare-Metal Startup & Linker        | 25     |/| Part A  | Bare-Metal Startup & Linker        | 20     |/g' "$NC_GATE_DIR/SCORE.md"
assert_mutation_fails "NC-1" "Score weights total 95 instead of 100" "bash '$NC_GATE_DIR/scripts/verify_gate.sh'"
cp "$GATE_DIR/SCORE.md" "$NC_GATE_DIR/SCORE.md"

# ------------------------------------------------------------------------------
# NC 2: Leaked reviewer link in learner-facing material
# ------------------------------------------------------------------------------
TARGET_LEAK="../reviewer/gate_solution.md"
echo "See [Reviewer Solution](${TARGET_LEAK}) for details." >> "$NC_GATE_DIR/part-a/README.md"
assert_mutation_fails "NC-2" "Learner-facing file contains direct link to reviewer solution" "bash '$NC_GATE_DIR/scripts/verify_gate.sh'"
cp "$GATE_DIR/part-a/README.md" "$NC_GATE_DIR/part-a/README.md"

# ------------------------------------------------------------------------------
# NC 3: Wrong source pin SHA in SOURCE_LEDGER.md
# ------------------------------------------------------------------------------
sed -i 's/9b777ae5c5b8e9e456065a00294d1e5f5f9facf5/0000000000000000000000000000000000000000/g' "$NC_GATE_DIR/SOURCE_LEDGER.md"
assert_mutation_fails "NC-3" "Invalid upstream FreeRTOS commit SHA in SOURCE_LEDGER.md" "bash '$NC_GATE_DIR/scripts/verify_gate.sh'"
cp "$GATE_DIR/SOURCE_LEDGER.md" "$NC_GATE_DIR/SOURCE_LEDGER.md"

# ------------------------------------------------------------------------------
# NC 4: Missing AI-Free rule in RULES.md
# ------------------------------------------------------------------------------
sed -i 's/AI-Free/Permitted-AI/g' "$NC_GATE_DIR/RULES.md"
assert_mutation_fails "NC-4" "RULES.md missing strict AI-Free policy" "bash '$NC_GATE_DIR/scripts/verify_gate.sh'"
cp "$GATE_DIR/RULES.md" "$NC_GATE_DIR/RULES.md"

# ------------------------------------------------------------------------------
# NC 5: Fixture missing mandatory SEEDED FIXTURE notice
# ------------------------------------------------------------------------------
sed -i 's/SEEDED FIXTURE \/ ASSESSMENT INPUT/OBSERVED TARGET CAPTURE/g' "$NC_GATE_DIR/part-b/fixtures/register_dump.txt"
assert_mutation_fails "NC-5" "Fixture pretends to be observed hardware capture without SEEDED notice" "bash '$NC_GATE_DIR/scripts/verify_gate.sh'"
cp "$GATE_DIR/part-b/fixtures/register_dump.txt" "$NC_GATE_DIR/part-b/fixtures/register_dump.txt"

# ------------------------------------------------------------------------------
# NC 6: Generic leak marker injected into learner README
# ------------------------------------------------------------------------------
echo "Seeded Defect: generic test failure marker" >> "$NC_GATE_DIR/part-a/README.md"
assert_mutation_fails "NC-6" "Learner README contains generic leak marker (Seeded Defect:)" "bash '$NC_GATE_DIR/scripts/verify_gate.sh'"
cp "$GATE_DIR/part-a/README.md" "$NC_GATE_DIR/part-a/README.md"

# ------------------------------------------------------------------------------
# NC 7: Generic canonical fix marker injected into learner source
# ------------------------------------------------------------------------------
echo "// Canonical Fix: fictitious solution snippet" >> "$NC_GATE_DIR/part-c/src/interrupt_config.c"
assert_mutation_fails "NC-7" "Learner source contains generic leak marker (Canonical Fix:)" "bash '$NC_GATE_DIR/scripts/verify_gate.sh'"
cp "$GATE_DIR/part-c/src/interrupt_config.c" "$NC_GATE_DIR/part-c/src/interrupt_config.c"

# ------------------------------------------------------------------------------
# NC 8: Source pin ownership swap between FreeRTOS and CMSIS-5
# ------------------------------------------------------------------------------
sed -i 's/9b777ae5c5b8e9e456065a00294d1e5f5f9facf5/TMP_SHA_PLACEHOLDER/g' "$NC_GATE_DIR/SOURCE_LEDGER.md"
sed -i 's/2b7495b8535bdcb306dac29b9ded4cfb679d7e5c/9b777ae5c5b8e9e456065a00294d1e5f5f9facf5/g' "$NC_GATE_DIR/SOURCE_LEDGER.md"
sed -i 's/TMP_SHA_PLACEHOLDER/2b7495b8535bdcb306dac29b9ded4cfb679d7e5c/g' "$NC_GATE_DIR/SOURCE_LEDGER.md"
assert_mutation_fails "NC-8" "Source pin ownership swap between FreeRTOS and CMSIS-5" "bash '$NC_GATE_DIR/scripts/verify_gate.sh'"
cp "$GATE_DIR/SOURCE_LEDGER.md" "$NC_GATE_DIR/SOURCE_LEDGER.md"

# ------------------------------------------------------------------------------
# NC 9: Wrong Part D floor with decoy '17.5' inside the exact same table cell
# ------------------------------------------------------------------------------
sed -i 's/\\ge \\mathbf{17.5 \/ 25} (70%)/\\ge \\mathbf{15.0 \/ 25} (historical bar 17.5)/g' "$NC_GATE_DIR/SCORE.md"
assert_mutation_fails "NC-9" "Wrong active Part D floor (15.0) with decoy 17.5 inside same cell" "bash '$NC_GATE_DIR/scripts/verify_gate.sh'"
cp "$GATE_DIR/SCORE.md" "$NC_GATE_DIR/SCORE.md"

# ------------------------------------------------------------------------------
# NC 10: Wrong Part A time budget with decoy '210' present in file
# ------------------------------------------------------------------------------
sed -i 's/45 min/40 min/g' "$NC_GATE_DIR/README.md"
assert_mutation_fails "NC-10" "Wrong Part A time budget (40m instead of 45m) with decoy 210 in file" "bash '$NC_GATE_DIR/scripts/verify_gate.sh'"
cp "$GATE_DIR/README.md" "$NC_GATE_DIR/README.md"

echo "=============================================================================="
echo ">>> ALL $NC_PASSED / $NC_TOTAL GENERIC NEGATIVE CONTROLS SUCCESSFULLY REJECTED <<<"
echo "=============================================================================="
