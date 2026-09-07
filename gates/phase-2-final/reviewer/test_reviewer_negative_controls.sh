#!/usr/bin/env bash
# ==============================================================================
# test_reviewer_negative_controls.sh: Reviewer Negative Controls Suite
# Mandated by Issue #25 & Leader Rework Round 3.
# Tests:
#   1. Reviewer isolation catching secret leaks and paraphrased answer patterns.
#   2. Reviewer regression oracle rejecting seeded defective fixtures.
#   3. Buildable decoy-oracle false-pass mutations (COMPILE PASS / ORACLE REJECT).
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=============================================================================="
echo "Running Phase 2 Gate Reviewer-Isolated Negative Controls"
echo "=============================================================================="

NC_PASSED=0
NC_TOTAL=14

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
# RNC 1: Part A secret injected into learner README
# ------------------------------------------------------------------------------
echo "Diagnosis note: sidata points to etext instead of data LMA" >> "$NC_GATE_DIR/part-a/README.md"
assert_reviewer_mutation_fails "RNC-1" "Learner README contains Part A secret (sidata points to etext)" "python3 '$NC_GATE_DIR/reviewer/verify_isolation.py'"
cp "$GATE_DIR/part-a/README.md" "$NC_GATE_DIR/part-a/README.md"

# ------------------------------------------------------------------------------
# RNC 2: Part B secret injected into learner C source comment
# ------------------------------------------------------------------------------
echo "/* Note: missing DMA_CCR_CIRC causes single-shot stall */" >> "$NC_GATE_DIR/part-b/src/dma.c"
assert_reviewer_mutation_fails "RNC-2" "Learner C source contains Part B secret (missing DMA_CCR_CIRC)" "python3 '$NC_GATE_DIR/reviewer/verify_isolation.py'"
cp "$GATE_DIR/part-b/src/dma.c" "$NC_GATE_DIR/part-b/src/dma.c"

# ------------------------------------------------------------------------------
# RNC 3: Part C secret injected into learner Makefile
# ------------------------------------------------------------------------------
echo '# Note: priority byte 0x40 is invalid under FreeRTOS' >> "$NC_GATE_DIR/part-c/Makefile"
assert_reviewer_mutation_fails "RNC-3" "Learner Makefile contains Part C secret (priority byte 0x40)" "python3 '$NC_GATE_DIR/reviewer/verify_isolation.py'"
cp "$GATE_DIR/part-c/Makefile" "$NC_GATE_DIR/part-c/Makefile"

# ------------------------------------------------------------------------------
# RNC 4: Part D paraphrased answer leak injected into learner README
# ------------------------------------------------------------------------------
echo "Analysis: the held synchronization resource is not released by storage" >> "$NC_GATE_DIR/part-d/README.md"
assert_reviewer_mutation_fails "RNC-4" "Learner README contains Part D paraphrased leak (held synchronization resource is not released)" "python3 '$NC_GATE_DIR/reviewer/verify_isolation.py'"
cp "$GATE_DIR/part-d/README.md" "$NC_GATE_DIR/part-d/README.md"

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
make -C "$GATE_DIR/part-d" clean all > /dev/null 2>&1

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
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-d '$GATE_DIR/part-d/src/node_app.c' '$GATE_DIR/part-d/fixtures/watchdog_reset_trace.txt' | grep -q '\[REFERENCE_PASS\]'"

# ==============================================================================
# Decoy False-Pass Negative Controls: COMPILE PASS / REVIEWER ORACLE REJECT
# ==============================================================================

# ------------------------------------------------------------------------------
# RNC 11: Part A Decoy Mutation — decoy LOADADDR symbol, active _sidata unchanged
# ------------------------------------------------------------------------------
cp "$GATE_DIR/part-a/linker/stm32f103c8tx_flash.ld" "$TEMP_TEST_DIR/part-a.ld.bak"
sed -i 's/_sidata = _etext;/_sidata = _etext; _decoy_sidata = LOADADDR(.data);/g' "$GATE_DIR/part-a/linker/stm32f103c8tx_flash.ld"
make -C "$GATE_DIR/part-a" clean all > /dev/null 2>&1
assert_reviewer_mutation_fails "RNC-11" "Part A decoy mutation: compiles cleanly, reviewer oracle rejects" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-a '$GATE_DIR/part-a/build/firmware.elf' | grep -q '\[REFERENCE_PASS\]'"
cp "$TEMP_TEST_DIR/part-a.ld.bak" "$GATE_DIR/part-a/linker/stm32f103c8tx_flash.ld"
make -C "$GATE_DIR/part-a" clean all > /dev/null 2>&1

# ------------------------------------------------------------------------------
# RNC 12: Part B Decoy Mutation — decoy CIRC definition, active CCR write unchanged
# ------------------------------------------------------------------------------
cp "$GATE_DIR/part-b/src/dma.c" "$TEMP_TEST_DIR/part-b.c.bak"
sed -i 's/void dma1_channel1_init(void)/volatile uint32_t g_decoy_circ = 0x5ae;\nvoid dma1_channel1_init(void)/g' "$GATE_DIR/part-b/src/dma.c"
make -C "$GATE_DIR/part-b" clean all > /dev/null 2>&1
assert_reviewer_mutation_fails "RNC-12" "Part B decoy mutation: compiles cleanly, reviewer oracle rejects" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-b '$GATE_DIR/part-b/build/firmware.elf' | grep -q '\[REFERENCE_PASS\]'"
cp "$TEMP_TEST_DIR/part-b.c.bak" "$GATE_DIR/part-b/src/dma.c"
make -C "$GATE_DIR/part-b" clean all > /dev/null 2>&1

# ------------------------------------------------------------------------------
# RNC 13: Part C Decoy Mutation — priority 6 on another IRQ, active EXTI0 priority 4
# ------------------------------------------------------------------------------
cp "$GATE_DIR/part-c/src/interrupt_config.c" "$TEMP_TEST_DIR/part-c.c.bak"
sed -i 's/NVIC_SetPriority(EXTI0_IRQn, 4);/NVIC_SetPriority(TIM2_IRQn, 6);\n    NVIC_SetPriority(EXTI0_IRQn, 4);/g' "$GATE_DIR/part-c/src/interrupt_config.c"
make -C "$GATE_DIR/part-c" clean all > /dev/null 2>&1
assert_reviewer_mutation_fails "RNC-13" "Part C decoy mutation: compiles cleanly, reviewer oracle rejects" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-c '$GATE_DIR/part-c/build/firmware.elf' | grep -q '\[REFERENCE_PASS\]'"
cp "$TEMP_TEST_DIR/part-c.c.bak" "$GATE_DIR/part-c/src/interrupt_config.c"
make -C "$GATE_DIR/part-c" clean all > /dev/null 2>&1

# ------------------------------------------------------------------------------
# RNC 14: Part D Decoy Mutation — give(xSensorBusLock) in dead helper, task_storage unchanged
# ------------------------------------------------------------------------------
cp "$GATE_DIR/part-d/src/node_app.c" "$TEMP_TEST_DIR/part-d.c.bak"
sed -i 's/void node_app_init(void)/void dummy_decoy_release(void) { xSemaphoreGive(xSensorBusLock); }\nvoid node_app_init(void)/g' "$GATE_DIR/part-d/src/node_app.c"
make -C "$GATE_DIR/part-d" clean all > /dev/null 2>&1
assert_reviewer_mutation_fails "RNC-14" "Part D decoy mutation: compiles cleanly, reviewer oracle rejects" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-d '$GATE_DIR/part-d/src/node_app.c' '$GATE_DIR/part-d/fixtures/watchdog_reset_trace.txt' | grep -q '\[REFERENCE_PASS\]'"
cp "$TEMP_TEST_DIR/part-d.c.bak" "$GATE_DIR/part-d/src/node_app.c"
make -C "$GATE_DIR/part-d" clean all > /dev/null 2>&1

echo "=============================================================================="
echo ">>> ALL $NC_PASSED / $NC_TOTAL REVIEWER NEGATIVE CONTROLS SUCCESSFULLY REJECTED <<<"
echo "=============================================================================="
