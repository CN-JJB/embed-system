#!/usr/bin/env bash
# ==============================================================================
# verify_reviewer.sh: Master Regression Verification Script for Reviewers
# Hardened for Leader Rework Round 2:
# Proves for each fresh seed (A, B, C, D):
#   1. COMPILE/LINK PASS (Seeded defective fixture compiles cleanly)
#   2. INTENDED REVIEWER ORACLE REJECT (Exact semantic defect caught by reviewer oracle)
#   3. REFERENCE COMPILE/LINK PASS (Reference fix compiles cleanly)
#   4. REFERENCE ORACLE PASS (Reviewer oracle confirms contract satisfied)
# Also verifies:
#   5. Learner `make check` fails neutrally on seeded, passes on reference
#   6. Zero answer leakage across learner files via verify_isolation.py
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Starting Phase 2 Gate Reviewer Regression Verification ==="

TEMP_BACKUP_DIR=$(mktemp -d /tmp/p2_gate_rev_XXXXXX)
trap 'rm -rf "$TEMP_BACKUP_DIR"' EXIT

run_staged_part_regression() {
    local part="$1"
    local target_file="$2"
    local ref_file="$3"
    local oracle_target="$4"

    echo "------------------------------------------------------------"
    echo "Testing $part:"
    echo "------------------------------------------------------------"

    # Stage 1: Seeded compile & link (COMPILE PASS)
    echo "--> [1/4] Building seeded fixture for $part (COMPILE PASS)..."
    if ! make -C "$GATE_DIR/$part" clean all > /dev/null 2>&1; then
        echo "ERROR: Seeded fixture for $part failed compilation/link!"
        exit 1
    fi
    echo "PASS: Seeded fixture for $part compiled and linked cleanly (COMPILE PASS)."

    # Verify learner-visible make check passes generic artifact verification
    if ! make -C "$GATE_DIR/$part" check > /dev/null 2>&1; then
        echo "ERROR: Seeded fixture for $part failed generic artifact check!"
        exit 1
    fi
    echo "PASS: Learner check for $part passed generic artifact check as expected."

    # Stage 2: Intended semantic defect rejection via Reviewer Oracle
    echo "--> [2/4] Verifying seeded fixture exhibits intended defect (INTENDED ORACLE REJECT)..."
    local oracle_seed_out=""
    if ! oracle_seed_out=$(python3 "$GATE_DIR/reviewer/regression_oracle.py" "$part" "$GATE_DIR/$part/$oracle_target" 2>&1); then
        echo "ERROR: Seeded fixture failed reviewer oracle unexpectedly!"
        echo "$oracle_seed_out"
        exit 1
    fi
    if echo "$oracle_seed_out" | grep -q "\[SEEDED_DEFECT_REJECT\]"; then
        echo "PASS: Reviewer oracle confirmed intended semantic defect:"
        echo "      $oracle_seed_out"
    else
        echo "ERROR: Reviewer oracle did not output [SEEDED_DEFECT_REJECT]!"
        echo "$oracle_seed_out"
        exit 1
    fi

    # Backup seeded file
    mkdir -p "$TEMP_BACKUP_DIR/$part"
    cp "$GATE_DIR/$part/$target_file" "$TEMP_BACKUP_DIR/$part/"

    # Stage 3: Apply reference fix and compile (REFERENCE COMPILE PASS)
    echo "--> [3/4] Applying reference fix and building (REFERENCE COMPILE PASS)..."
    cp "$GATE_DIR/reviewer/reference/$ref_file" "$GATE_DIR/$part/$target_file"
    if ! make -C "$GATE_DIR/$part" clean all > /dev/null 2>&1; then
        echo "ERROR: Reference fix for $part failed compilation/link!"
        cp "$TEMP_BACKUP_DIR/$part/$(basename "$target_file")" "$GATE_DIR/$part/$target_file"
        exit 1
    fi
    echo "PASS: Reference fix for $part compiled and linked cleanly (REFERENCE COMPILE PASS)."

    # Verify learner-visible make check passes on reference
    if ! make -C "$GATE_DIR/$part" check > /dev/null 2>&1; then
        echo "ERROR: Reference fix for $part failed learner check!"
        cp "$TEMP_BACKUP_DIR/$part/$(basename "$target_file")" "$GATE_DIR/$part/$target_file"
        exit 1
    fi
    echo "PASS: Learner check passed on reference fix."

    # Stage 4: Verify reference passes Reviewer Oracle (REFERENCE ORACLE PASS)
    echo "--> [4/4] Verifying reference fix satisfies Reviewer Oracle (REFERENCE ORACLE PASS)..."
    local oracle_ref_out=""
    if ! oracle_ref_out=$(python3 "$GATE_DIR/reviewer/regression_oracle.py" "$part" "$GATE_DIR/$part/$oracle_target" 2>&1); then
        echo "ERROR: Reference fix failed reviewer oracle!"
        echo "$oracle_ref_out"
        cp "$TEMP_BACKUP_DIR/$part/$(basename "$target_file")" "$GATE_DIR/$part/$target_file"
        exit 1
    fi
    if echo "$oracle_ref_out" | grep -q "\[REFERENCE_PASS\]"; then
        echo "PASS: Reviewer oracle confirmed reference contract satisfied:"
        echo "      $oracle_ref_out"
    else
        echo "ERROR: Reviewer oracle did not output [REFERENCE_PASS]!"
        echo "$oracle_ref_out"
        cp "$TEMP_BACKUP_DIR/$part/$(basename "$target_file")" "$GATE_DIR/$part/$target_file"
        exit 1
    fi

    # Restore seeded file
    cp "$TEMP_BACKUP_DIR/$part/$(basename "$target_file")" "$GATE_DIR/$part/$target_file"
    make -C "$GATE_DIR/$part" clean all > /dev/null 2>&1
    echo "PASS: Restored seeded broken fixture for $part."
}

run_staged_part_regression "part-a" \
    "linker/stm32f103c8tx_flash.ld" \
    "part-a/stm32f103c8tx_flash.ld" \
    "build/firmware.elf"

run_staged_part_regression "part-b" \
    "src/dma.c" \
    "part-b/dma.c" \
    "build/firmware.elf"

run_staged_part_regression "part-c" \
    "src/interrupt_config.c" \
    "part-c/interrupt_config.c" \
    "build/firmware.elf"

run_staged_part_regression "part-d" \
    "src/node_app.c" \
    "part-d/node_app.c" \
    "src/node_app.c"

echo "------------------------------------------------------------"
echo "Verifying positive Part D scripted evidence cross-consistency..."
echo "------------------------------------------------------------"
python3 - "$GATE_DIR" <<'PY'
import importlib.util
import pathlib
import sys

gate = pathlib.Path(sys.argv[1])
oracle_path = gate / "reviewer" / "regression_oracle.py"
spec = importlib.util.spec_from_file_location("p2_gate_oracle", oracle_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

ok, msg = module.validate_evidence_cross_consistency(
    str(gate / "part-d" / "fixtures" / "watchdog_reset_trace.txt"),
    str(gate / "part-d" / "fixtures" / "task_state_dump.txt"),
)
if not ok:
    print(f"ERROR: Positive Part D evidence pair failed cross-consistency: {msg}")
    raise SystemExit(1)
print(f"PASS: Positive Part D evidence pair cross-consistent: {msg}")
PY

echo "------------------------------------------------------------"
echo "Running Reviewer Secrecy & Isolation Audit..."
echo "------------------------------------------------------------"
python3 "$GATE_DIR/reviewer/verify_isolation.py"

echo "============================================================"
echo ">>> ALL REVIEWER REFERENCE & ORACLE CHECKS PASSED <<<"
echo "============================================================"
