#!/usr/bin/env bash
# ==============================================================================
# verify_reviewer.sh: Master Regression Verification Script for Reviewers
# Tests:
#   1. Seeded defective fixtures fail their respective checks as intended.
#   2. Reference solutions pass all automated checks with zero errors.
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

    echo "------------------------------------------------------------"
    echo "Testing $part:"
    echo "------------------------------------------------------------"

    # 1. Test seeded failure
    echo "--> [1/4] Building seeded broken fixture for $part..."
    make -C "$GATE_DIR/$part" clean all > /dev/null

    echo "--> [2/4] Verifying seeded broken fixture exhibits intended failure..."
    if make -C "$GATE_DIR/$part" check > /dev/null 2>&1; then
        echo "ERROR: Seeded broken fixture for $part unexpectedly passed check!"
        exit 1
    else
        echo "PASS: Seeded broken fixture for $part correctly failed check."
    fi

    # 2. Backup seeded file
    mkdir -p "$TEMP_BACKUP_DIR/$part"
    cp "$GATE_DIR/$part/$target_file" "$TEMP_BACKUP_DIR/$part/"

    # 3. Apply reference fix
    echo "--> [3/4] Applying reference fix for $part..."
    cp "$GATE_DIR/reviewer/reference/$ref_file" "$GATE_DIR/$part/$target_file"

    # 4. Test reference pass
    echo "--> [4/4] Verifying reference fix passes check..."
    make -C "$GATE_DIR/$part" clean all > /dev/null
    if ! make -C "$GATE_DIR/$part" check; then
        echo "ERROR: Reference fix for $part failed check!"
        # Restore backup before exiting
        cp "$TEMP_BACKUP_DIR/$part/$(basename "$target_file")" "$GATE_DIR/$part/$target_file"
        exit 1
    fi
    echo "PASS: Reference fix for $part successfully passed all checks."

    # Restore seeded file
    cp "$TEMP_BACKUP_DIR/$part/$(basename "$target_file")" "$GATE_DIR/$part/$target_file"
    make -C "$GATE_DIR/$part" clean all > /dev/null
    echo "PASS: Restored seeded broken fixture for $part."
}

run_part_regression "part-a" "linker/stm32f103c8tx_flash.ld" "part-a/stm32f103c8tx_flash.ld"
run_part_regression "part-b" "src/dma.c" "part-b/dma.c"
run_part_regression "part-c" "src/interrupt_config.c" "part-c/interrupt_config.c"
run_part_regression "part-d" "src/node_app.c" "part-d/node_app.c"

echo "============================================================"
echo ">>> ALL REVIEWER REFERENCE & ORACLE CHECKS PASSED <<<"
echo "============================================================"
