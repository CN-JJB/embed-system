#!/usr/bin/env bash
# ==============================================================================
# test_reviewer_negative_controls.sh: Reviewer Negative Controls Suite
# Mandated by Issue #25 & Leader Rework Round 4.
# Tests:
#   1. Reviewer isolation catching secret leaks and paraphrased answer patterns.
#   2. Reviewer regression oracle rejecting seeded defective fixtures.
#   3. Buildable decoy-oracle false-pass mutations:
#      Enforces COMPILE PASS / ORACLE EXECUTION PASS / INTENDED REJECT.
#      Distinguishes semantic rejection from parser ERROR / UNEXPECTED_FAILURE.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=============================================================================="
echo "Running Phase 2 Gate Reviewer-Isolated Negative Controls (Round 4)"
echo "=============================================================================="

NC_PASSED=0
NC_TOTAL=18

TEMP_TEST_DIR=$(mktemp -d /tmp/p2_reviewer_nc_XXXXXX)
trap 'rm -rf "$TEMP_TEST_DIR"' EXIT

# Copy the gate package into a temporary test environment for isolation tests
cp -r "$GATE_DIR" "$TEMP_TEST_DIR/phase-2-final"
NC_GATE_DIR="$TEMP_TEST_DIR/phase-2-final"

assert_isolation_mutation_fails() {
    local nc_id="$1"
    local desc="$2"
    local command_to_run="$3"

    echo "------------------------------------------------------------"
    echo "Running Isolation Negative Control $nc_id: $desc"
    
    if eval "$command_to_run" > /dev/null 2>&1; then
        echo "FAIL: Isolation Negative Control $nc_id unexpectedly PASSED!"
        exit 1
    else
        echo "PASS: Isolation Negative Control $nc_id was correctly REJECTED."
        NC_PASSED=$((NC_PASSED + 1))
    fi
}

assert_oracle_rejects_seeded() {
    local nc_id="$1"
    local desc="$2"
    local oracle_cmd="$3"

    echo "------------------------------------------------------------"
    echo "Running Seeded Fixture Negative Control $nc_id: $desc"
    local oracle_out
    oracle_out=$(eval "$oracle_cmd" 2>&1)

    if echo "$oracle_out" | grep -q -E "\[ERROR\]|\[UNEXPECTED_FAILURE\]|Traceback"; then
        echo "FAIL: Seed $nc_id caused unexpected oracle execution failure: $oracle_out"
        exit 1
    fi

    if echo "$oracle_out" | grep -q "\[SEEDED_DEFECT_REJECT\]"; then
        echo "PASS: Seed $nc_id confirmed intended defect: [SEEDED_DEFECT_REJECT]"
        NC_PASSED=$((NC_PASSED + 1))
    else
        echo "FAIL: Seed $nc_id did not produce [SEEDED_DEFECT_REJECT]! Output: $oracle_out"
        exit 1
    fi
}

assert_reviewer_decoy_rejected() {
    local nc_id="$1"
    local desc="$2"
    local build_cmd="$3"
    local oracle_cmd="$4"

    echo "------------------------------------------------------------"
    echo "Running Decoy Negative Control $nc_id: $desc"

    # Step 1: COMPILE PASS (mutation must compile and link cleanly)
    if ! eval "$build_cmd" > /dev/null 2>&1; then
        echo "FAIL: Decoy $nc_id failed to compile/link!"
        exit 1
    fi
    echo "  -> [COMPILE PASS]"

    # Step 2: ORACLE EXECUTION PASS & INTENDED REJECT
    local oracle_out
    oracle_out=$(eval "$oracle_cmd" 2>&1)

    # Oracle must NOT crash or return parser ERROR / UNEXPECTED_FAILURE
    if echo "$oracle_out" | grep -q -E "\[ERROR\]|\[UNEXPECTED_FAILURE\]|Traceback|SyntaxError"; then
        echo "FAIL: Decoy $nc_id caused oracle parser/runtime failure:"
        echo "$oracle_out"
        exit 1
    fi
    echo "  -> [ORACLE EXECUTION PASS]"

    # Oracle must explicitly return [SEEDED_DEFECT_REJECT] (and NEVER [REFERENCE_PASS])
    if echo "$oracle_out" | grep -q "\[SEEDED_DEFECT_REJECT\]"; then
        echo "  -> [INTENDED ORACLE REJECT]: $oracle_out"
        echo "PASS: Decoy $nc_id verified: COMPILE PASS / ORACLE EXECUTION PASS / INTENDED REJECT"
        NC_PASSED=$((NC_PASSED + 1))
    else
        echo "FAIL: Decoy $nc_id did not produce [SEEDED_DEFECT_REJECT]!"
        echo "Output was: $oracle_out"
        exit 1
    fi
}

assert_trace_decoy_rejected() {
    local nc_id="$1"
    local desc="$2"
    local oracle_cmd="$3"

    echo "------------------------------------------------------------"
    echo "Running Isolated Trace Decoy Control $nc_id: $desc"
    local oracle_out
    oracle_out=$(eval "$oracle_cmd" 2>&1)

    # Step 1: ORACLE EXECUTION PASS (Must not crash, raise SyntaxError, or return parser ERROR / UNEXPECTED_FAILURE)
    if echo "$oracle_out" | grep -q -E "\[ERROR\]|\[UNEXPECTED_FAILURE\]|Traceback|SyntaxError"; then
        echo "FAIL: Trace Decoy $nc_id caused oracle execution failure:"
        echo "$oracle_out"
        exit 1
    fi
    echo "  -> [ORACLE EXECUTION PASS]"

    # Step 2: Must never falsely award REFERENCE_PASS
    if echo "$oracle_out" | grep -q "\[REFERENCE_PASS\]"; then
        echo "FAIL: Trace Decoy $nc_id received [REFERENCE_PASS] unexpectedly!"
        echo "$oracle_out"
        exit 1
    fi

    # Step 3: Must produce dedicated, identifiable trace consistency rejection
    if echo "$oracle_out" | grep -q "Watchdog trace consistency check failed:"; then
        echo "  -> [INTENDED ORACLE REJECT]: $oracle_out"
        echo "PASS: Trace Decoy $nc_id verified: dedicated trace consistency reject confirmed."
        NC_PASSED=$((NC_PASSED + 1))
    else
        echo "FAIL: Trace Decoy $nc_id did not produce dedicated trace-consistency rejection! Output: $oracle_out"
        exit 1
    fi
}

assert_evidence_contradiction_rejected() {
    local nc_id="$1"
    local desc="$2"
    local oracle_cmd="$3"

    echo "------------------------------------------------------------"
    echo "Running Evidence Contradiction Negative Control $nc_id: $desc"
    local oracle_out
    oracle_out=$(eval "$oracle_cmd" 2>&1)

    # Step 1: ORACLE EXECUTION PASS (Must not crash, raise SyntaxError, or return parser ERROR / UNEXPECTED_FAILURE)
    if echo "$oracle_out" | grep -q -E "\[ERROR\]|\[UNEXPECTED_FAILURE\]|Traceback|SyntaxError"; then
        echo "FAIL: Evidence Contradiction $nc_id caused oracle execution failure:"
        echo "$oracle_out"
        exit 1
    fi
    echo "  -> [ORACLE EXECUTION PASS]"

    # Step 2: Must never falsely award REFERENCE_PASS
    if echo "$oracle_out" | grep -q "\[REFERENCE_PASS\]"; then
        echo "FAIL: Evidence Contradiction $nc_id received [REFERENCE_PASS] unexpectedly!"
        echo "$oracle_out"
        exit 1
    fi

    # Step 3: Must produce dedicated, identifiable evidence cross-consistency rejection
    if echo "$oracle_out" | grep -q "Evidence cross-consistency check failed:"; then
        echo "  -> [INTENDED ORACLE REJECT]: $oracle_out"
        echo "PASS: Evidence Contradiction $nc_id verified: dedicated evidence-consistency reject confirmed."
        NC_PASSED=$((NC_PASSED + 1))
    else
        echo "FAIL: Evidence Contradiction $nc_id did not produce dedicated evidence-consistency rejection! Output: $oracle_out"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# RNC 1: Part A secret injected into learner README
# ------------------------------------------------------------------------------
echo "Diagnosis note: sidata points to etext instead of data LMA" >> "$NC_GATE_DIR/part-a/README.md"
assert_isolation_mutation_fails "RNC-1" "Learner README contains Part A secret (sidata points to etext)" "python3 '$NC_GATE_DIR/reviewer/verify_isolation.py'"
cp "$GATE_DIR/part-a/README.md" "$NC_GATE_DIR/part-a/README.md"

# ------------------------------------------------------------------------------
# RNC 2: Part B secret injected into learner C source comment
# ------------------------------------------------------------------------------
echo "/* Note: missing DMA_CCR_CIRC causes single-shot stall */" >> "$NC_GATE_DIR/part-b/src/dma.c"
assert_isolation_mutation_fails "RNC-2" "Learner C source contains Part B secret (missing DMA_CCR_CIRC)" "python3 '$NC_GATE_DIR/reviewer/verify_isolation.py'"
cp "$GATE_DIR/part-b/src/dma.c" "$NC_GATE_DIR/part-b/src/dma.c"

# ------------------------------------------------------------------------------
# RNC 3: Part C secret injected into learner Makefile
# ------------------------------------------------------------------------------
echo '# Note: priority byte 0x40 is invalid under FreeRTOS' >> "$NC_GATE_DIR/part-c/Makefile"
assert_isolation_mutation_fails "RNC-3" "Learner Makefile contains Part C secret (priority byte 0x40)" "python3 '$NC_GATE_DIR/reviewer/verify_isolation.py'"
cp "$GATE_DIR/part-c/Makefile" "$NC_GATE_DIR/part-c/Makefile"

# ------------------------------------------------------------------------------
# RNC 4: Part D paraphrased answer leak injected into learner README
# ------------------------------------------------------------------------------
echo "Analysis: the held synchronization resource is not released by storage" >> "$NC_GATE_DIR/part-d/README.md"
assert_isolation_mutation_fails "RNC-4" "Learner README contains Part D paraphrased leak (held synchronization resource is not released)" "python3 '$NC_GATE_DIR/reviewer/verify_isolation.py'"
cp "$GATE_DIR/part-d/README.md" "$NC_GATE_DIR/part-d/README.md"

# ------------------------------------------------------------------------------
# RNC 5: Prohibited reviewer filename in top-level README
# ------------------------------------------------------------------------------
echo "Reference: see gate_solution.md" >> "$NC_GATE_DIR/README.md"
assert_isolation_mutation_fails "RNC-5" "Top-level README references prohibited reviewer file (gate_solution.md)" "python3 '$NC_GATE_DIR/reviewer/verify_isolation.py'"
cp "$GATE_DIR/README.md" "$NC_GATE_DIR/README.md"

# ------------------------------------------------------------------------------
# RNC 6: Generic leak marker injected into learner README
# ------------------------------------------------------------------------------
echo "Root Cause: defect identified during inspection" >> "$NC_GATE_DIR/part-b/README.md"
assert_isolation_mutation_fails "RNC-6" "Learner README contains generic leak marker (Root Cause:)" "python3 '$NC_GATE_DIR/reviewer/verify_isolation.py'"
cp "$GATE_DIR/part-b/README.md" "$NC_GATE_DIR/part-b/README.md"

# ------------------------------------------------------------------------------
# Build seeded binaries in repository tree for oracle tests
# ------------------------------------------------------------------------------
make -C "$GATE_DIR/part-a" clean all > /dev/null 2>&1
make -C "$GATE_DIR/part-b" clean all > /dev/null 2>&1
make -C "$GATE_DIR/part-c" clean all > /dev/null 2>&1
make -C "$GATE_DIR/part-d" clean all > /dev/null 2>&1

# ------------------------------------------------------------------------------
# RNC 7: Reviewer Oracle Part A rejects seeded build
# ------------------------------------------------------------------------------
assert_oracle_rejects_seeded "RNC-7" "Reviewer Oracle Part A rejects seeded build" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-a '$GATE_DIR/part-a/build/firmware.elf'"

# ------------------------------------------------------------------------------
# RNC 8: Reviewer Oracle Part B rejects seeded build
# ------------------------------------------------------------------------------
assert_oracle_rejects_seeded "RNC-8" "Reviewer Oracle Part B rejects seeded build" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-b '$GATE_DIR/part-b/build/firmware.elf'"

# ------------------------------------------------------------------------------
# RNC 9: Reviewer Oracle Part C rejects seeded build
# ------------------------------------------------------------------------------
assert_oracle_rejects_seeded "RNC-9" "Reviewer Oracle Part C rejects seeded build" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-c '$GATE_DIR/part-c/build/firmware.elf'"

# ------------------------------------------------------------------------------
# RNC 10: Reviewer Oracle Part D rejects seeded source
# ------------------------------------------------------------------------------
assert_oracle_rejects_seeded "RNC-10" "Reviewer Oracle Part D rejects seeded source" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-d '$GATE_DIR/part-d/src/node_app.c' '$GATE_DIR/part-d/fixtures/watchdog_reset_trace.txt'"

# ==============================================================================
# Decoy False-Pass Negative Controls: COMPILE PASS / ORACLE EXECUTION PASS / INTENDED REJECT
# ==============================================================================

# ------------------------------------------------------------------------------
# RNC 11: Part A Decoy Mutation — decoy LOADADDR symbol, active _sidata unchanged
# ------------------------------------------------------------------------------
cp "$GATE_DIR/part-a/linker/stm32f103c8tx_flash.ld" "$TEMP_TEST_DIR/part-a.ld.bak"
sed -i 's/_sidata = ADDR(.data);/_sidata = ADDR(.data); _decoy_sidata = LOADADDR(.data);/g' "$GATE_DIR/part-a/linker/stm32f103c8tx_flash.ld"
assert_reviewer_decoy_rejected "RNC-11" "Part A decoy: _decoy_sidata = LOADADDR(.data) while _sidata remains ADDR(.data)" \
    "make -C '$GATE_DIR/part-a' clean all" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-a '$GATE_DIR/part-a/build/firmware.elf'"
cp "$TEMP_TEST_DIR/part-a.ld.bak" "$GATE_DIR/part-a/linker/stm32f103c8tx_flash.ld"
make -C "$GATE_DIR/part-a" clean all > /dev/null 2>&1

# ------------------------------------------------------------------------------
# RNC 12: Part B Decoy Mutation — unrelated-base store with offset #8 and valid value 0x5AE
# ------------------------------------------------------------------------------
cp "$GATE_DIR/part-b/src/dma.c" "$TEMP_TEST_DIR/part-b.c.bak"
sed -i 's/volatile uint32_t g_dma_ht_count = 0;/volatile uint32_t g_decoy_mmio[4];\nvolatile uint32_t g_dma_ht_count = 0;/g' "$GATE_DIR/part-b/src/dma.c"
sed -i 's/DMA1_Channel1->CCR &= ~DMA_CCR_EN;/DMA1_Channel1->CCR \&= ~DMA_CCR_EN;\n    g_decoy_mmio[2] = 0x5AE;/g' "$GATE_DIR/part-b/src/dma.c"
assert_reviewer_decoy_rejected "RNC-12" "Part B decoy: unrelated-base store g_decoy_mmio[2]=0x5AE (offset 8) while active CCR lacks CIRC" \
    "make -C '$GATE_DIR/part-b' clean all" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-b '$GATE_DIR/part-b/build/firmware.elf'"
cp "$TEMP_TEST_DIR/part-b.c.bak" "$GATE_DIR/part-b/src/dma.c"
make -C "$GATE_DIR/part-b" clean all > /dev/null 2>&1

# ------------------------------------------------------------------------------
# RNC 13: Part C Decoy Mutation — unrelated-base store with offset #6 and valid priority 0x60
# ------------------------------------------------------------------------------
cp "$GATE_DIR/part-c/src/interrupt_config.c" "$TEMP_TEST_DIR/part-c.c.bak"
sed -i 's/void interrupt_config_init(void)/volatile uint8_t g_decoy_nvic[16];\nvoid interrupt_config_init(void)/g' "$GATE_DIR/part-c/src/interrupt_config.c"
sed -i 's/NVIC_SetPriority(EXTI0_IRQn, 4);/g_decoy_nvic[6] = 0x60;\n    NVIC_SetPriority(EXTI0_IRQn, 4);/g' "$GATE_DIR/part-c/src/interrupt_config.c"
assert_reviewer_decoy_rejected "RNC-13" "Part C decoy: unrelated-base store g_decoy_nvic[6]=0x60 (offset 6) while active EXTI0 priority is 4 (0x40)" \
    "make -C '$GATE_DIR/part-c' clean all" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-c '$GATE_DIR/part-c/build/firmware.elf'"
cp "$TEMP_TEST_DIR/part-c.c.bak" "$GATE_DIR/part-c/src/interrupt_config.c"
make -C "$GATE_DIR/part-c" clean all > /dev/null 2>&1

# ------------------------------------------------------------------------------
# RNC 14: Part D Decoy Mutation — in-function dead-branch release while active path leaks
# ------------------------------------------------------------------------------
cp "$GATE_DIR/part-d/src/node_app.c" "$TEMP_TEST_DIR/part-d.c.bak"
sed -i 's/xSemaphoreGive(xLogBufferLock);/if (0) { xSemaphoreGive(xSensorBusLock); }\n            xSemaphoreGive(xLogBufferLock);/g' "$GATE_DIR/part-d/src/node_app.c"
assert_reviewer_decoy_rejected "RNC-14" "Part D decoy: give(xSensorBusLock) in dead branch if (0) while active path leaks mutex" \
    "make -C '$GATE_DIR/part-d' clean all" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-d '$GATE_DIR/part-d/src/node_app.c' '$GATE_DIR/part-d/fixtures/watchdog_reset_trace.txt'"
cp "$TEMP_TEST_DIR/part-d.c.bak" "$GATE_DIR/part-d/src/node_app.c"
make -C "$GATE_DIR/part-d" clean all > /dev/null 2>&1

# ------------------------------------------------------------------------------
# RNC 15: Part D Decoy Mutation — buildable runtime conditional-path release
# ------------------------------------------------------------------------------
cp "$GATE_DIR/part-d/src/node_app.c" "$TEMP_TEST_DIR/part-d.c.bak"
cp "$GATE_DIR/reviewer/reference/part-d/node_app.c" "$GATE_DIR/part-d/src/node_app.c"
sed -i 's/xSemaphoreGive(xSensorBusLock);/if (g_storage_cycles > 5) { xSemaphoreGive(xSensorBusLock); }/g' "$GATE_DIR/part-d/src/node_app.c"
assert_reviewer_decoy_rejected "RNC-15" "Part D decoy: conditional release if (g_storage_cycles > 5) leaves acquire path leaked" \
    "make -C '$GATE_DIR/part-d' clean all" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-d '$GATE_DIR/part-d/src/node_app.c' '$GATE_DIR/part-d/fixtures/watchdog_reset_trace.txt'"
cp "$TEMP_TEST_DIR/part-d.c.bak" "$GATE_DIR/part-d/src/node_app.c"
make -C "$GATE_DIR/part-d" clean all > /dev/null 2>&1

# ------------------------------------------------------------------------------
# RNC 16: Part D Isolated Trace Mutation — otherwise-reference-pass source, mutated trace
# ------------------------------------------------------------------------------
cp "$GATE_DIR/part-d/fixtures/watchdog_reset_trace.txt" "$TEMP_TEST_DIR/trace.txt.bak"
# Mutate trace timestamp to break monotonicity and phase ordering (0.050s -> 0.150s)
sed -i 's/t = 0.050 s/t = 0.150 s/g' "$GATE_DIR/part-d/fixtures/watchdog_reset_trace.txt"
# Run against reference node_app.c which otherwise achieves REFERENCE_PASS
assert_trace_decoy_rejected "RNC-16" "Part D isolated trace: reference source paired with non-monotonic trace" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-d '$GATE_DIR/reviewer/reference/part-d/node_app.c' '$GATE_DIR/part-d/fixtures/watchdog_reset_trace.txt'"
cp "$TEMP_TEST_DIR/trace.txt.bak" "$GATE_DIR/part-d/fixtures/watchdog_reset_trace.txt"

# ------------------------------------------------------------------------------
# RNC 17: Part D Decoy Mutation — reachable early exit before later cleanup
# ------------------------------------------------------------------------------
cp "$GATE_DIR/part-d/src/node_app.c" "$TEMP_TEST_DIR/part-d-rnc17.c.bak"
cp "$GATE_DIR/reviewer/reference/part-d/node_app.c" "$GATE_DIR/part-d/src/node_app.c"
python3 -c "
with open('$GATE_DIR/part-d/src/node_app.c', 'r') as f:
    c = f.read()
c = c.replace('g_storage_cycles++;\n            /*', 'if (g_storage_cycles > 10) { return; }\n            g_storage_cycles++;\n            /*')
with open('$GATE_DIR/part-d/src/node_app.c', 'w') as f:
    f.write(c)
"
assert_reviewer_decoy_rejected "RNC-17" "Part D decoy: reachable early exit before later cleanup leaves acquire path leaked" \
    "make -C '$GATE_DIR/part-d' clean all" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-d '$GATE_DIR/part-d/src/node_app.c' '$GATE_DIR/part-d/fixtures/watchdog_reset_trace.txt' '$GATE_DIR/part-d/fixtures/task_state_dump.txt'"
cp "$TEMP_TEST_DIR/part-d-rnc17.c.bak" "$GATE_DIR/part-d/src/node_app.c"
make -C "$GATE_DIR/part-d" clean all > /dev/null 2>&1

# ------------------------------------------------------------------------------
# RNC 18: Part D Evidence Contradiction Mutation — timing trace intact, mutated task state dump
# ------------------------------------------------------------------------------
cp "$GATE_DIR/part-d/fixtures/task_state_dump.txt" "$TEMP_TEST_DIR/task_state_dump.txt.bak"
# Mutate task state dump: claim xMutexHolder is unheld (0x0) while timing trace proves Task_Storage holds and leaks it
sed -i 's/xMutexHolder = 0x20000300,/xMutexHolder = 0x00000000,/g' "$GATE_DIR/part-d/fixtures/task_state_dump.txt"
# Run against reference node_app.c (which otherwise achieves REFERENCE_PASS)
assert_evidence_contradiction_rejected "RNC-18" "Part D evidence contradiction: intact timing trace paired with unheld mutex in state dump" \
    "python3 '$GATE_DIR/reviewer/regression_oracle.py' part-d '$GATE_DIR/reviewer/reference/part-d/node_app.c' '$GATE_DIR/part-d/fixtures/watchdog_reset_trace.txt' '$GATE_DIR/part-d/fixtures/task_state_dump.txt'"
cp "$TEMP_TEST_DIR/task_state_dump.txt.bak" "$GATE_DIR/part-d/fixtures/task_state_dump.txt"

echo "=============================================================================="
echo ">>> ALL $NC_PASSED / $NC_TOTAL REVIEWER NEGATIVE CONTROLS SUCCESSFULLY REJECTED <<<"
echo "=============================================================================="
