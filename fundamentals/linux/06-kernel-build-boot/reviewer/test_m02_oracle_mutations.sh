#!/bin/bash
set -euo pipefail

# P3-M02 Assessment Oracle Mutation Regression (REVIEWER-ONLY)
# Enforces, for the assessment oracle itself:
#   REFERENCE fixture  -> intended PASS
#   mutated artifact   -> intended semantic REJECT
#   crash / unrelated failure -> must NOT be counted as a successful reject
#
# Round 3 adversarial additions:
#   - expected config text present ONLY as a decoy/comment while the
#     effective state is wrong -> REJECT
#   - contradictory duplicate states for one constrained symbol -> REJECT
#   - expected-drift symbol missing from vmlinux -> REJECT (missing, not drift)
#
# Round 4 adversarial additions (parent-shell existence state):
#   - missing NON-DRIFT (expected-MATCH) symbol in vmlinux -> REJECT
#   - duplicate NON-DRIFT (expected-MATCH) symbol in System.map -> REJECT
#   These must reject even when the remaining observed drift set still
#   equals the expected drift set (the prior false-pass class).
#
# Every test is graded as PREP PASS / ORACLE EXECUTION PASS / INTENDED RESULT.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M02_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M02_ROOT"

CROSS_COMPILE="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}"
if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    echo "ERROR: Cross compiler '${CROSS_COMPILE}gcc' not found in PATH." >&2
    exit 1
fi

ORACLE="bash reviewer/oracle_m02.sh"
REJECT_PATTERN="ASSESSMENT MISMATCH"
PASS_PATTERN="ASSESSMENT REFERENCE PASS"

GEN_CHALLENGE="reviewer/scripts/generate_m02_challenge_fixtures.sh"
GEN_GATE="reviewer/scripts/generate_m02_gate_fixtures.sh"

TOTAL_TESTS=12
PASSED_TESTS=0

materialize() {
    bash "$GEN_CHALLENGE" challenge/fixtures "$CROSS_COMPILE"
    bash "$GEN_GATE" gate/fixtures "$CROSS_COMPILE"
}

# Link a mutated challenge vmlinux from assembly on stdin. Leaves
# candidate_System.map untouched so existence defects are isolated from
# map-side drift edits.
link_mutated_challenge_vmlinux() {
    local tmpd
    tmpd=$(mktemp -d)
    cat > "$tmpd/mut_syms.S"
    cat > "$tmpd/mut.lds" << 'EOF'
OUTPUT_ARCH(arm)
ENTRY(stext)
SECTIONS
{
	. = 0xC0008000;
	.head.text : { *(.head.text) }
	. = 0xC0800000;
	.text : { *(.text) }
	.rodata : { *(.rodata*) }
	.data : { *(.data*) }
	.bss : { *(.bss*) }
}
EOF
    "${CROSS_COMPILE}gcc" -c "$tmpd/mut_syms.S" -o "$tmpd/mut.o"
    "${CROSS_COMPILE}gcc" -nostdlib -static -Wl,--build-id=none -T "$tmpd/mut.lds" "$tmpd/mut.o" -o challenge/fixtures/candidate_vmlinux
    rm -rf "$tmpd"
}

# Rebuild the challenge vmlinux WITHOUT the symbol the seed expects to drift,
# while leaving the System.map untouched. The oracle must REJECT for a
# missing symbol, not accept the empty comparison as drift.
prep_missing_drift_symbol() {
    materialize
    link_mutated_challenge_vmlinux << 'EOF'
/* SYNTHETIC PEDAGOGICAL STATIC FIXTURE — NOT A LINUX KERNEL BUILD */
	.arm
	.section .head.text, "ax"
	.globl stext
stext:
	b	__create_page_tables

	.globl __create_page_tables
__create_page_tables:
	bx	lr

	.globl __enable_mmu
__enable_mmu:
	b	__mmap_switched

	.globl __mmap_switched
__mmap_switched:
	b	start_kernel

	.section .text, "ax"
	.globl start_kernel
start_kernel:
	bl	setup_arch
	b	rest_init

	.globl setup_arch
setup_arch:
	bx	lr

	.globl rest_init
rest_init:
	b	kernel_init

	.globl kernel_init
kernel_init:
	bx	lr
EOF
}

# Remove an audited MATCH (non-drift) symbol from vmlinux, keep the
# expected-drift symbol, leave System.map untouched. A subshell-lossy
# fail() would skip this symbol and still observe the exact expected
# drift set — that false-pass is the Round 4 defect.
prep_missing_nondrift_symbol() {
    materialize
    link_mutated_challenge_vmlinux << 'EOF'
/* SYNTHETIC PEDAGOGICAL STATIC FIXTURE — NOT A LINUX KERNEL BUILD */
	.arm
	.section .head.text, "ax"
	.globl stext
stext:
	b	__create_page_tables

	.globl __create_page_tables
__create_page_tables:
	bx	lr

	.globl __enable_mmu
__enable_mmu:
	b	__mmap_switched

	.globl __mmap_switched
__mmap_switched:
	b	start_kernel

	.section .text, "ax"
	.globl start_kernel
start_kernel:
	bl	console_init
	b	rest_init

	.globl console_init
console_init:
	bx	lr

	.globl rest_init
rest_init:
	b	kernel_init

	.globl kernel_init
kernel_init:
	bx	lr
EOF
}

# Duplicate an audited MATCH (non-drift) symbol in System.map. The
# expected-drift symbol is left as a single drifted entry so a
# skip-on-empty lookup would still produce the expected drift set.
prep_duplicate_nondrift_symbol() {
    materialize
    awk '
        $3 == "setup_arch" {
            print
            print "c080aaaa", $2, $3
            next
        }
        { print }
    ' challenge/fixtures/candidate_System.map > challenge/fixtures/candidate_System.map.dup
    mv challenge/fixtures/candidate_System.map.dup challenge/fixtures/candidate_System.map
}

run_oracle_expect() {
    local test_id="$1"
    local desc="$2"
    local prep_cmd="$3"
    local expect_kind="$4"   # PASS | REJECT
    local extra_pattern="${5:-}"  # optional extra semantic-reject regex
    local out=""
    local rc=0

    echo "------------------------------------------------------------------"
    echo "Test ${test_id}: ${desc}"

    if ! eval "$prep_cmd" >/dev/null 2>&1; then
        echo "[TEST ${test_id} FAIL] Fixture prep stage failed!"
        return 1
    fi
    echo "  PREP: PASS"

    set +e
    out=$($ORACLE 2>&1)
    rc=$?
    set -e

    if [ "$rc" -ge 128 ]; then
        echo "[TEST ${test_id} FAIL] Oracle crashed with signal $((rc - 128))!"
        echo "$out"
        return 1
    fi
    echo "  ORACLE EXECUTION: PASS (no crash, exit $rc)"

    case "$expect_kind" in
        PASS)
            if [ "$rc" -ne 0 ] || ! echo "$out" | grep -q "$PASS_PATTERN"; then
                echo "[TEST ${test_id} FAIL] Expected oracle PASS (exit 0, pattern '${PASS_PATTERN}')."
                echo "  Exit code: $rc"
                echo "$out"
                return 1
            fi
            echo "  INTENDED RESULT: PASS (reference accepted)"
            ;;
        REJECT)
            if [ "$rc" -eq 0 ]; then
                echo "[TEST ${test_id} FAIL] Oracle falsely PASSED a mutated artifact!"
                echo "$out"
                return 1
            fi
            if ! echo "$out" | grep -Eq "$REJECT_PATTERN"; then
                echo "[TEST ${test_id} FAIL] Oracle reject output does not match intended semantic pattern '${REJECT_PATTERN}'."
                echo "  Exit code: $rc"
                echo "$out"
                return 1
            fi
            if [ -n "$extra_pattern" ] && ! echo "$out" | grep -Eq "$extra_pattern"; then
                echo "[TEST ${test_id} FAIL] Oracle reject output does not match required semantic detail '${extra_pattern}'."
                echo "  Exit code: $rc"
                echo "$out"
                return 1
            fi
            echo "  INTENDED RESULT: semantic REJECT (pattern matched, exit $rc)"
            ;;
    esac

    PASSED_TESTS=$((PASSED_TESTS + 1))
    return 0
}

# Test 1: reference fixture set -> oracle must PASS
run_oracle_expect \
    1 \
    "Reference assessment fixtures accepted by oracle" \
    "materialize" \
    "PASS"

# Test 2: challenge config mutated — seeded deviation removed (state replaced)
run_oracle_expect \
    2 \
    "Challenge config mutated (seeded deviation removed)" \
    "materialize; sed -i 's/^CONFIG_ARM_LPAE=y/# CONFIG_ARM_LPAE is not set/' challenge/fixtures/candidate_effective.config" \
    "REJECT"

# Test 3: expected text present only as decoy/comment, effective state wrong
run_oracle_expect \
    3 \
    "Challenge config decoy: expected text only in a comment while effective state is wrong" \
    "materialize; sed -i 's/^CONFIG_ARM_LPAE=y$/# CONFIG_ARM_LPAE=y (decoy note)/' challenge/fixtures/candidate_effective.config; printf '# CONFIG_ARM_LPAE is not set\n' >> challenge/fixtures/candidate_effective.config" \
    "REJECT"

# Test 4: contradictory duplicate states for one constrained symbol
run_oracle_expect \
    4 \
    "Challenge config contradictory duplicate states for one symbol" \
    "materialize; printf '# CONFIG_ARM_LPAE is not set\n' >> challenge/fixtures/candidate_effective.config" \
    "REJECT"

# Test 5: expected-drift symbol missing from vmlinux -> REJECT as missing, not drift
run_oracle_expect \
    5 \
    "Challenge vmlinux missing the expected-drift symbol" \
    "prep_missing_drift_symbol" \
    "REJECT" \
    "MISSING"

# Test 6: missing NON-DRIFT (expected-MATCH) symbol; expected-drift symbol preserved
run_oracle_expect \
    6 \
    "Challenge vmlinux missing a non-drift (expected-MATCH) symbol" \
    "prep_missing_nondrift_symbol" \
    "REJECT" \
    "setup_arch MISSING"

# Test 7: duplicate NON-DRIFT (expected-MATCH) symbol in System.map
run_oracle_expect \
    7 \
    "Challenge System.map duplicates a non-drift (expected-MATCH) symbol" \
    "prep_duplicate_nondrift_symbol" \
    "REJECT" \
    "setup_arch has .* entries — ambiguous"

# Test 8: challenge System.map mutated — expected drift repaired
run_oracle_expect \
    8 \
    "Challenge System.map mutated (seeded drift repaired)" \
    "materialize; \$(command -v ${CROSS_COMPILE}nm || echo nm) -n challenge/fixtures/candidate_vmlinux | awk '{print \$1, \$2, \$3}' > challenge/fixtures/candidate_System.map" \
    "REJECT"

# Test 9: gate config mutated — expected deviation removed
run_oracle_expect \
    9 \
    "Gate config mutated (seeded deviation removed)" \
    "materialize; sed -i 's/^# CONFIG_VIRTIO_BLK is not set/CONFIG_VIRTIO_BLK=y/' gate/fixtures/gate_effective.config" \
    "REJECT"

# Test 10: gate System.map mutated — drift moved to a different symbol
run_oracle_expect \
    10 \
    "Gate System.map mutated (drift moved to an unintended symbol)" \
    "materialize; \$(command -v ${CROSS_COMPILE}nm || echo nm) -n gate/fixtures/gate_vmlinux | awk '{if (\$3 == \"start_kernel\") print \"c0809000\", \$2, \$3; else print \$1, \$2, \$3}' > gate/fixtures/gate_System.map" \
    "REJECT"

# Test 11: gate zImage mutated — magic corrupted
run_oracle_expect \
    11 \
    "Gate zImage mutated (boot magic corrupted)" \
    "materialize; python3 -c 'import struct; b = bytearray(64); struct.pack_into(\"<I\", b, 0x24, 0xdeadbeef); open(\"gate/fixtures/gate_zImage\", \"wb\").write(b)'" \
    "REJECT"

# Test 12: guard — unrelated oracle failure must not be counted as a semantic reject
# (bogus toolchain makes the oracle exit nonzero with an environment error that
#  does NOT carry the semantic reject pattern)
echo "------------------------------------------------------------------"
echo "Test 12: Unrelated oracle failure must not count as semantic reject"
if ! materialize >/dev/null 2>&1; then
    echo "[TEST 12 FAIL] Fixture prep stage failed!"
    exit 1
fi
echo "  PREP: PASS"

set +e
GUARD_OUT=$(CROSS_COMPILE=guard-nonexistent-toolchain- bash reviewer/oracle_m02.sh 2>&1)
GUARD_RC=$?
set -e

if [ "$GUARD_RC" -ge 128 ]; then
    echo "[TEST 12 FAIL] Oracle crashed with signal $((GUARD_RC - 128))!"
    echo "$GUARD_OUT"
    exit 1
fi
if [ "$GUARD_RC" -eq 0 ]; then
    echo "[TEST 12 FAIL] Oracle falsely PASSED a broken environment!"
    echo "$GUARD_OUT"
    exit 1
fi
if echo "$GUARD_OUT" | grep -Eq "$REJECT_PATTERN"; then
    echo "[TEST 12 FAIL] Unrelated failure was miscounted as a semantic reject!"
    echo "$GUARD_OUT"
    exit 1
fi
echo "  GUARD RESULT: unrelated failure correctly NOT counted as semantic reject (exit $GUARD_RC)"
PASSED_TESTS=$((PASSED_TESTS + 1))

echo "------------------------------------------------------------------"
if [ "$PASSED_TESTS" -eq "$TOTAL_TESTS" ]; then
    echo "=== ALL P3-M02 ASSESSMENT ORACLE REGRESSION TESTS PASSED (${PASSED_TESTS}/${TOTAL_TESTS}) ==="
    exit 0
else
    echo "=== ERROR: Only ${PASSED_TESTS}/${TOTAL_TESTS} oracle regression tests passed! ===" >&2
    exit 1
fi
