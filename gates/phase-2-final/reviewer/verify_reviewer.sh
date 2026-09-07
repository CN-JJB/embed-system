#!/usr/bin/env bash
# ==============================================================================
# verify_reviewer.sh: Master Regression Verification Script for Reviewers
# Tests:
#   1. Seeded defective fixtures compile cleanly (COMPILE PASS).
#   2. Seeded fixtures fail specifically for the intended semantic defect (INTENDED SEMANTIC DEFECT REJECT).
#   3. Reference solutions pass all automated checks with zero errors (REFERENCE PASS).
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Starting Phase 2 Gate Reviewer Regression Verification ==="

TEMP_BACKUP_DIR=$(mktemp -d /tmp/p2_gate_rev_XXXXXX)
trap 'rm -rf "$TEMP_BACKUP_DIR"' EXIT

run_part_regression() {
    local part="$1"
    local target_file="$2"
    local ref_file="$3"
    local expected_fail_pattern="$4"
    local expected_pass_pattern="$5"

    echo "------------------------------------------------------------"
    echo "Testing $part:"
    echo "------------------------------------------------------------"

    # 1. Test seeded compile/build (COMPILE PASS)
    echo "--> [1/4] Building seeded fixture for $part..."
    if ! make -C "$GATE_DIR/$part" clean all > /dev/null 2>&1; then
        echo "ERROR: Seeded fixture for $part failed compilation/link!"
        exit 1
    fi
    echo "PASS: Seeded fixture for $part compiled and linked cleanly (COMPILE PASS)."

    # 2. Test intended semantic defect failure (INTENDED SEMANTIC DEFECT REJECT)
    echo "--> [2/4] Verifying seeded fixture exhibits intended semantic defect..."
    local check_output=""
    if check_output=$(make -C "$GATE_DIR/$part" check 2>&1); then
        echo "ERROR: Seeded broken fixture for $part unexpectedly passed check!"
        echo "$check_output"
        exit 1
    else
        if echo "$check_output" | grep -Eq "$expected_fail_pattern"; then
            echo "PASS: Seeded fixture for $part failed specifically for intended semantic reason:"
            echo "      Pattern matched: '$expected_fail_pattern'"
        else
            echo "ERROR: Seeded fixture for $part failed for unexpected reason!"
            echo "Expected pattern: '$expected_fail_pattern'"
            echo "Actual output:"
            echo "$check_output"
            exit 1
        fi
    fi

    # 3. Backup seeded file
    mkdir -p "$TEMP_BACKUP_DIR/$part"
    cp "$GATE_DIR/$part/$target_file" "$TEMP_BACKUP_DIR/$part/"

    # 4. Apply reference fix
    echo "--> [3/4] Applying reference fix for $part..."
    cp "$GATE_DIR/reviewer/reference/$ref_file" "$GATE_DIR/$part/$target_file"

    # 5. Test reference pass (REFERENCE PASS)
    echo "--> [4/4] Verifying reference fix passes check..."
    if ! make -C "$GATE_DIR/$part" clean all > /dev/null 2>&1; then
        echo "ERROR: Reference fix for $part failed compilation/link!"
        cp "$TEMP_BACKUP_DIR/$part/$(basename "$target_file")" "$GATE_DIR/$part/$target_file"
        exit 1
    fi

    local ref_output=""
    if ! ref_output=$(make -C "$GATE_DIR/$part" check 2>&1); then
        echo "ERROR: Reference fix for $part failed check!"
        echo "$ref_output"
        cp "$TEMP_BACKUP_DIR/$part/$(basename "$target_file")" "$GATE_DIR/$part/$target_file"
        exit 1
    fi

    if echo "$ref_output" | grep -Eq "$expected_pass_pattern"; then
        echo "PASS: Reference fix for $part passed check with expected contract confirmation:"
        echo "      Pattern matched: '$expected_pass_pattern'"
    else
        echo "ERROR: Reference fix for $part passed check but output lacked expected contract confirmation!"
        echo "Expected pattern: '$expected_pass_pattern'"
        echo "Actual output:"
        echo "$ref_output"
        cp "$TEMP_BACKUP_DIR/$part/$(basename "$target_file")" "$GATE_DIR/$part/$target_file"
        exit 1
    fi

    # Restore seeded file
    cp "$TEMP_BACKUP_DIR/$part/$(basename "$target_file")" "$GATE_DIR/$part/$target_file"
    make -C "$GATE_DIR/$part" clean all > /dev/null 2>&1
    echo "PASS: Restored seeded broken fixture for $part."
}

run_part_regression "part-a" \
    "linker/stm32f103c8tx_flash.ld" \
    "part-a/stm32f103c8tx_flash.ld" \
    "Part A LMA mismatch: _sidata" \
    "Part A Linker LMA contract verified"

run_part_regression "part-b" \
    "src/dma.c" \
    "part-b/dma.c" \
    "DMA1_Channel1->CCR does not enable circular mode \(DMA_CCR_CIRC\)" \
    "DMA1_Channel1->CCR enables circular mode"

run_part_regression "part-c" \
    "src/interrupt_config.c" \
    "part-c/interrupt_config.c" \
    "EXTI0_IRQn configured with priority byte 0x00" \
    "safe for FreeRTOS"

run_part_regression "part-d" \
    "src/node_app.c" \
    "part-d/node_app.c" \
    "Inverted lock acquisition hierarchy in task_storage" \
    "Canonical lock hierarchy verified"

echo "============================================================"
echo ">>> ALL REVIEWER REFERENCE & ORACLE CHECKS PASSED <<<"
echo "============================================================"
