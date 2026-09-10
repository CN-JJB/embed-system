#!/bin/bash
set -euo pipefail

# Adversarial Mutation Test Suite for the P3-M04 component validators.
# Verifies that every launch-configuration defect class is semantically
# REJECTED (not crashed) by the manifest contract validator and that static
# teaching-log analysis stays separate from runtime evidence verification.
#
# The candidate submission format is the DATA-ONLY manifest, so contract
# mutations are manifest mutations. Non-declarative/shell content is itself a
# rejected defect class (no candidate may smuggle an invocation).

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

echo "================================================================"
echo "=== Running P3-M04 Adversarial Mutation Suite (Round 2)       ==="
echo "================================================================"

WORK_DIR=$(mktemp -d /tmp/m04_mutations_XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

VALID_MANIFEST="$WORK_DIR/valid_manifest.conf"
cat << 'EOF' > "$VALID_MANIFEST"
# Canonical reference manifest (component-validator positive control).
MACHINE=virt,highmem=off,gic-version=2
CPU=cortex-a7
MEM=512M
SMP=1
NOGRAPHIC=true
BOOTARGS=earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init
EOF

VALID_LOG="$M04_ROOT/fixtures/reference_boot.log"

MUTATION_COUNT=0
PASS_COUNT=0

mutate_manifest() {
    # mutate_manifest <outfile> <sed-expression...>
    local out="$1"; shift
    sed "$@" "$VALID_MANIFEST" > "$out"
}

assert_contract_rejected() {
    local name="$1" file="$2"
    MUTATION_COUNT=$((MUTATION_COUNT + 1))
    echo -n "[TEST] Mutation $MUTATION_COUNT: $name ... "

    set +e
    OUTPUT=$(bash "$M04_ROOT/scripts/verify_boot_contract.sh" "$file" 2>&1)
    RC=$?
    set -e

    if [ $RC -ne 0 ] && echo "$OUTPUT" | grep -q "REJECT"; then
        echo "PASS (Intended Semantic REJECT)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL (Unexpected Pass or Crash: RC=$RC)"
        echo "$OUTPUT"
        exit 1
    fi
}

assert_milestone_rejected() {
    local name="$1" file="$2"
    MUTATION_COUNT=$((MUTATION_COUNT + 1))
    echo -n "[TEST] Mutation $MUTATION_COUNT: $name ... "

    set +e
    OUTPUT=$(bash "$M04_ROOT/scripts/audit_boot_milestones.sh" "$file" 2>&1)
    RC=$?
    set -e

    if [ $RC -ne 0 ] && echo "$OUTPUT" | grep -q "REJECT"; then
        echo "PASS (Intended Semantic REJECT)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL (Unexpected Pass or Crash: RC=$RC)"
        echo "$OUTPUT"
        exit 1
    fi
}

assert_runtime_rejected() {
    local name="$1" file="$2"
    local bootargs="${3:-earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init}"
    MUTATION_COUNT=$((MUTATION_COUNT + 1))
    echo -n "[TEST] Mutation $MUTATION_COUNT: $name ... "

    set +e
    OUTPUT=$(bash "$M04_ROOT/scripts/verify_runtime_boot.sh" "$file" "$bootargs" 2>&1)
    RC=$?
    set -e

    if [ $RC -ne 0 ] && grep -q "REJECT" <<<"$OUTPUT"; then
        echo "PASS (Intended Semantic REJECT)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL (Unexpected Pass or Crash: RC=$RC)"
        echo "$OUTPUT"
        exit 1
    fi
}

# 1. Silent-boot family: wrong console (output routed off the serial device)
#    and no earlycon to make early execution visible.
MUT1="$WORK_DIR/mut1_wrong_console.conf"
mutate_manifest "$MUT1" 's/^BOOTARGS=.*/BOOTARGS=console=ttyS0,115200 rdinit=\/init/'
assert_contract_rejected "Wrong console (ttyS0) and no earlycon" "$MUT1"

# 2. Conflicting consoles: canonical contract requires exactly one console=
#    token. Real Linux resolves repeated same-type consoles first-of-type,
#    not last-wins, so duplicates/conflicts are not canonical.
MUT2="$WORK_DIR/mut2_conflicting_consoles.conf"
mutate_manifest "$MUT2" 's/^BOOTARGS=.*/BOOTARGS=earlycon=pl011,0x09000000 console=ttyAMA0,115200 console=ttyS0 rdinit=\/init/'
assert_contract_rejected "Duplicate console= tokens (canonical requires exactly one)" "$MUT2"

# 2b. Duplicate identical console tokens are still rejected (exactly-one).
MUT2B="$WORK_DIR/mut2b_duplicate_same_console.conf"
mutate_manifest "$MUT2B" 's/^BOOTARGS=.*/BOOTARGS=earlycon=pl011,0x09000000 console=ttyAMA0,115200 console=ttyAMA0,115200 rdinit=\/init/'
assert_contract_rejected "Duplicate identical console= tokens" "$MUT2B"

# 3. Machine defects: missing highmem=off, missing gic-version=2, and a
#    decoy comment carrying the canonical string.
MUT3="$WORK_DIR/mut3_missing_highmem.conf"
mutate_manifest "$MUT3" 's/^MACHINE=.*/MACHINE=virt,gic-version=2/'
assert_contract_rejected "MACHINE missing required highmem=off" "$MUT3"

MUT4="$WORK_DIR/mut4_missing_gic.conf"
mutate_manifest "$MUT4" 's/^MACHINE=.*/MACHINE=virt,highmem=off/'
assert_contract_rejected "MACHINE missing required gic-version=2" "$MUT4"

MUT4D="$WORK_DIR/mut4d_decoy_comment.conf"
{ echo "# decoy: MACHINE=virt,highmem=off,gic-version=2"; cat "$MUT3"; } > "$MUT4D"
assert_contract_rejected "Decoy comment carrying the canonical machine string" "$MUT4D"

# 4. CPU defects: wrong CPU and commented-out declaration (not a declaration).
MUT5="$WORK_DIR/mut5_wrong_cpu.conf"
mutate_manifest "$MUT5" 's/^CPU=.*/CPU=cortex-a15/'
assert_contract_rejected "Wrong CPU (cortex-a15)" "$MUT5"

MUT5C="$WORK_DIR/mut5c_commented_cpu.conf"
mutate_manifest "$MUT5C" 's/^CPU=/# CPU=/'
assert_contract_rejected "CPU declaration commented out (missing key)" "$MUT5C"

# 5. RAM / SMP defects.
MUT6="$WORK_DIR/mut6_wrong_mem.conf"
mutate_manifest "$MUT6" 's/^MEM=.*/MEM=256M/'
assert_contract_rejected "Non-canonical RAM (256M)" "$MUT6"

MUT7="$WORK_DIR/mut7_wrong_smp.conf"
mutate_manifest "$MUT7" 's/^SMP=.*/SMP=2/'
assert_contract_rejected "Non-canonical SMP (2)" "$MUT7"

# 6. Display/serial route defect: headless serial console required.
MUT8="$WORK_DIR/mut8_graphics.conf"
mutate_manifest "$MUT8" 's/^NOGRAPHIC=.*/NOGRAPHIC=false/'
assert_contract_rejected "NOGRAPHIC=false (display not headless)" "$MUT8"

# 7. Bootargs defects: missing earlycon, missing rdinit, wrong rdinit path.
MUT9="$WORK_DIR/mut9_missing_earlycon.conf"
mutate_manifest "$MUT9" 's/^BOOTARGS=.*/BOOTARGS=console=ttyAMA0,115200 rdinit=\/init/'
assert_contract_rejected "Missing earlycon parameter" "$MUT9"

MUT10="$WORK_DIR/mut10_missing_rdinit.conf"
mutate_manifest "$MUT10" 's/^BOOTARGS=.*/BOOTARGS=earlycon=pl011,0x09000000 console=ttyAMA0,115200/'
assert_contract_rejected "Missing rdinit=/init selector" "$MUT10"

MUT11="$WORK_DIR/mut11_wrong_rdinit.conf"
mutate_manifest "$MUT11" 's#^BOOTARGS=.*#BOOTARGS=earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init-bad#'
assert_contract_rejected "rdinit selector is not the canonical /init" "$MUT11"

# 8. Manifest-integrity defects: an unknown key, a duplicate key, and
#    non-declarative shell content (an invocation smuggled next to correct
#    declarations) must all REJECT.
MUT12="$WORK_DIR/mut12_unknown_key.conf"
{ cat "$VALID_MANIFEST"; echo "EXTRA_QEMU_ARGS=-serial mon:stdio"; } > "$MUT12"
assert_contract_rejected "Unknown launch key present" "$MUT12"

MUT13="$WORK_DIR/mut13_duplicate_key.conf"
{ cat "$VALID_MANIFEST"; echo "MEM=256M"; } > "$MUT13"
assert_contract_rejected "Duplicate MEM definition (conflicting values)" "$MUT13"

MUT14="$WORK_DIR/mut14_shell_content.conf"
{ cat "$VALID_MANIFEST"; echo 'qemu-system-arm -machine vexpress-a9 -cpu cortex-a15 -m 256M -smp 2'; } > "$MUT14"
assert_contract_rejected "Shell invocation smuggled into the data-only manifest" "$MUT14"

MUT15="$WORK_DIR/mut15_substitution.conf"
mutate_manifest "$MUT15" 's#^MEM=.*#MEM=$(echo 256M)#'
assert_contract_rejected "Command substitution inside a manifest value" "$MUT15"

# 9. Log-analysis defects (static teaching analyzer).
MUT16_LOG="$WORK_DIR/mut16_truncated.log"
head -n 20 "$VALID_LOG" > "$MUT16_LOG"
assert_milestone_rejected "Truncated boot log (premature silence / timeout)" "$MUT16_LOG"

MUT17_LOG="$WORK_DIR/mut17_inverted.log"
tac "$VALID_LOG" > "$MUT17_LOG"
assert_milestone_rejected "Chronological milestone ordering inversion" "$MUT17_LOG"

# 10. Runtime-evidence defects: forged milestone text passes the STATIC
#     teaching analyzer by design, but the RUNTIME verifier must REJECT it.
MUT18_LOG="$WORK_DIR/mut18_forged_milestones.log"
printf '%s\n' \
    "Linux version 6.18.50" \
    "CPU: ARMv7 Processor" \
    "Kernel command line: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init" \
    "printk: console [ttyAMA0] enabled" \
    "Trying to unpack rootfs image as initramfs" \
    "Run /init as init process" \
    "REAL-BUSYBOX-INIT-READY" > "$MUT18_LOG"
assert_runtime_rejected "Forged concatenated milestone text (no runtime binding)" "$MUT18_LOG"

MUT19_LOG="$WORK_DIR/mut19_wrong_cmdline.log"
cp "$VALID_LOG" "$MUT19_LOG"
sed -i 's/console=ttyAMA0,115200/console=ttyS0,115200/' "$MUT19_LOG"
assert_runtime_rejected "Logged command line mismatches expected bootargs" "$MUT19_LOG"

# 11. Positive reference controls.
echo -n "[TEST] Positive Reference Control: canonical manifest ... "
set +e
REF_OUTPUT=$(bash "$M04_ROOT/scripts/verify_boot_contract.sh" "$VALID_MANIFEST" 2>&1)
REF_RC=$?
set -e
if [ $REF_RC -eq 0 ] && echo "$REF_OUTPUT" | grep -q "fully VERIFIED"; then
    echo "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "FAIL (Valid reference failed to pass!)"
    echo "$REF_OUTPUT"
    exit 1
fi

echo -n "[TEST] Positive Reference Control: reference boot log (static) ... "
set +e
LOG_OUTPUT=$(bash "$M04_ROOT/scripts/audit_boot_milestones.sh" "$VALID_LOG" 2>&1)
LOG_RC=$?
set -e
if [ $LOG_RC -eq 0 ] && echo "$LOG_OUTPUT" | grep -q "boot milestones verified"; then
    echo "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "FAIL (Valid reference log failed to pass!)"
    echo "$LOG_OUTPUT"
    exit 1
fi

echo -n "[TEST] Positive Reference Control: reference boot log (runtime) ... "
set +e
RT_OUTPUT=$(bash "$M04_ROOT/scripts/verify_runtime_boot.sh" "$VALID_LOG" "earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init" 2>&1)
RT_RC=$?
set -e
if [ $RT_RC -eq 0 ] && echo "$RT_OUTPUT" | grep -q "Runtime boot evidence VERIFIED"; then
    echo "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "FAIL (Valid reference log failed runtime verification!)"
    echo "$RT_OUTPUT"
    exit 1
fi

echo "================================================================"
echo "=== ALL $PASS_COUNT P3-M04 MUTATION & REFERENCE CHECKS PASSED ==="
echo "================================================================"
