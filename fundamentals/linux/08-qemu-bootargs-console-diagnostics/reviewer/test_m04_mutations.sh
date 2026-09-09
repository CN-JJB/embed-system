#!/bin/bash
set -euo pipefail

# Adversarial Mutation Test Suite for P3-M04 Validators & Grading Oracle
# Verifies that every bootargs/machine defect class is semantically REJECTED (not crashed).

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

echo "================================================================"
echo "=== Running P3-M04 Adversarial Mutation Suite                ==="
echo "================================================================"

WORK_DIR=$(mktemp -d /tmp/m04_mutations_XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

VALID_CONFIG="$WORK_DIR/valid_config.sh"
cat << 'EOF' > "$VALID_CONFIG"
#!/bin/bash
# Canonical Reference Launch
MACHINE="-machine virt,highmem=off,gic-version=2"
CPU="-cpu cortex-a7"
MEM="-m 512M"
SMP="-smp 1"
DISPLAY_OPT="-nographic"
BOOTARGS="earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init"
qemu-system-arm $MACHINE $CPU $MEM $SMP $DISPLAY_OPT -kernel "$KERNEL" -initrd "$INITRD" -append "$BOOTARGS"
EOF
chmod 755 "$VALID_CONFIG"

VALID_LOG="$M04_ROOT/fixtures/reference_boot.log"

MUTATION_COUNT=0
PASS_COUNT=0

assert_contract_rejected() {
    local name="$1"
    local file="$2"
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
    local name="$1"
    local file="$2"
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
    local name="$1"
    local file="$2"
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

# 1. Mutation: Correct console in comment, but command uses wrong console (ttyS0)
MUT1="$WORK_DIR/mut1_decoy_comment.sh"
cat << 'EOF' > "$MUT1"
#!/bin/bash
# Decoy comment: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init
MACHINE="-machine virt,highmem=off,gic-version=2"
CPU="-cpu cortex-a7"
MEM="-m 512M"
SMP="-smp 1"
DISPLAY_OPT="-nographic"
BOOTARGS="earlycon=pl011,0x09000000 console=ttyS0,115200 rdinit=/init"
qemu-system-arm $MACHINE $CPU $MEM $SMP $DISPLAY_OPT -kernel "$KERNEL" -initrd "$INITRD" -append "$BOOTARGS"
EOF
assert_contract_rejected "Decoy console in comment with wrong effective console" "$MUT1"

# 2. Mutation: Conflicting consoles (duplicate console= tokens). Canonical
# contract requires exactly one console=ttyAMA0,115200; real Linux resolves
# repeated same-type consoles first-of-type, not last-wins.
MUT2="$WORK_DIR/mut2_conflicting_consoles.sh"
cat << 'EOF' > "$MUT2"
#!/bin/bash
MACHINE="-machine virt,highmem=off,gic-version=2"
CPU="-cpu cortex-a7"
MEM="-m 512M"
SMP="-smp 1"
DISPLAY_OPT="-nographic"
BOOTARGS="earlycon=pl011,0x09000000 console=ttyAMA0,115200 console=ttyS0 rdinit=/init"
qemu-system-arm $MACHINE $CPU $MEM $SMP $DISPLAY_OPT -kernel "$KERNEL" -initrd "$INITRD" -append "$BOOTARGS"
EOF
assert_contract_rejected "Duplicate console= tokens (canonical requires exactly one)" "$MUT2"

# 2b. Mutation: Duplicate SAME console twice is still rejected (exactly-one).
MUT2B="$WORK_DIR/mut2b_duplicate_same_console.sh"
cat << 'EOF' > "$MUT2B"
#!/bin/bash
MACHINE="-machine virt,highmem=off,gic-version=2"
CPU="-cpu cortex-a7"
MEM="-m 512M"
SMP="-smp 1"
DISPLAY_OPT="-nographic"
BOOTARGS="earlycon=pl011,0x09000000 console=ttyAMA0,115200 console=ttyAMA0,115200 rdinit=/init"
qemu-system-arm $MACHINE $CPU $MEM $SMP $DISPLAY_OPT -kernel "$KERNEL" -initrd "$INITRD" -append "$BOOTARGS"
EOF
assert_contract_rejected "Duplicate identical console= tokens" "$MUT2B"

# 3. Mutation: Missing highmem=off
MUT3="$WORK_DIR/mut3_missing_highmem.sh"
cat << 'EOF' > "$MUT3"
#!/bin/bash
MACHINE="-machine virt,gic-version=2"
CPU="-cpu cortex-a7"
MEM="-m 512M"
SMP="-smp 1"
DISPLAY_OPT="-nographic"
BOOTARGS="earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init"
qemu-system-arm $MACHINE $CPU $MEM $SMP $DISPLAY_OPT -kernel "$KERNEL" -initrd "$INITRD" -append "$BOOTARGS"
EOF
assert_contract_rejected "Missing required highmem=off flag" "$MUT3"

# 4. Mutation: Missing gic-version=2
MUT4="$WORK_DIR/mut4_missing_gic.sh"
cat << 'EOF' > "$MUT4"
#!/bin/bash
MACHINE="-machine virt,highmem=off"
CPU="-cpu cortex-a7"
MEM="-m 512M"
SMP="-smp 1"
DISPLAY_OPT="-nographic"
BOOTARGS="earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init"
qemu-system-arm $MACHINE $CPU $MEM $SMP $DISPLAY_OPT -kernel "$KERNEL" -initrd "$INITRD" -append "$BOOTARGS"
EOF
assert_contract_rejected "Missing required gic-version=2 flag" "$MUT4"

# 5. Mutation: Wrong CPU (cortex-a15 instead of cortex-a7)
MUT5="$WORK_DIR/mut5_wrong_cpu.sh"
cat << 'EOF' > "$MUT5"
#!/bin/bash
MACHINE="-machine virt,highmem=off,gic-version=2"
CPU="-cpu cortex-a15"
MEM="-m 512M"
SMP="-smp 1"
DISPLAY_OPT="-nographic"
BOOTARGS="earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init"
qemu-system-arm $MACHINE $CPU $MEM $SMP $DISPLAY_OPT -kernel "$KERNEL" -initrd "$INITRD" -append "$BOOTARGS"
EOF
assert_contract_rejected "Wrong CPU (cortex-a15)" "$MUT5"

# 6. Mutation: Missing earlycon
MUT6="$WORK_DIR/mut6_missing_earlycon.sh"
cat << 'EOF' > "$MUT6"
#!/bin/bash
MACHINE="-machine virt,highmem=off,gic-version=2"
CPU="-cpu cortex-a7"
MEM="-m 512M"
SMP="-smp 1"
DISPLAY_OPT="-nographic"
BOOTARGS="console=ttyAMA0,115200 rdinit=/init"
qemu-system-arm $MACHINE $CPU $MEM $SMP $DISPLAY_OPT -kernel "$KERNEL" -initrd "$INITRD" -append "$BOOTARGS"
EOF
assert_contract_rejected "Missing earlycon parameter" "$MUT6"

# 7. Mutation: Truncated boot log (timeout / silence before PID 1 milestone)
MUT7_LOG="$WORK_DIR/mut7_truncated.log"
head -n 20 "$VALID_LOG" > "$MUT7_LOG"
assert_milestone_rejected "Truncated boot log (premature silence / timeout)" "$MUT7_LOG"

# 8. Mutation: Chronological ordering violation in boot log
MUT8_LOG="$WORK_DIR/mut8_inverted.log"
tac "$VALID_LOG" > "$MUT8_LOG"
assert_milestone_rejected "Chronological milestone ordering inversion" "$MUT8_LOG"

# 8b. Mutation: Forged/concatenated milestone text (ordered strings only).
# Passes the STATIC teaching auditor by design, but the RUNTIME verifier
# must REJECT it (no cmdline binding, handoff, memory, userspace response).
MUT8B_LOG="$WORK_DIR/mut8b_forged_milestones.log"
printf '%s\n' \
    "Linux version 6.18.50" \
    "CPU: ARMv7 Processor" \
    "Kernel command line: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init" \
    "printk: console [ttyAMA0] enabled" \
    "Trying to unpack rootfs image as initramfs" \
    "Run /init as init process" \
    "REAL-BUSYBOX-INIT-READY" > "$MUT8B_LOG"
assert_runtime_rejected "Forged concatenated milestone text (no runtime binding)" "$MUT8B_LOG"

# 8c. Mutation: Valid kernel prefix but wrong command line (log/config
# mismatch). Runtime verifier must REJECT when the logged cmdline lacks
# the expected tokens.
MUT8C_LOG="$WORK_DIR/mut8c_wrong_cmdline.log"
cp "$VALID_LOG" "$MUT8C_LOG"
sed -i 's/console=ttyAMA0,115200/console=ttyS0,115200/' "$MUT8C_LOG"
assert_runtime_rejected "Logged command line mismatches expected bootargs" "$MUT8C_LOG"

# 9. Positive Reference Control: Unmodified reference configuration must PASS
echo -n "[TEST] Positive Reference Control: Valid boot configuration ... "
set +e
REF_OUTPUT=$(bash "$M04_ROOT/scripts/verify_boot_contract.sh" "$VALID_CONFIG" 2>&1)
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

# 10. Positive Reference Control: Unmodified reference log must PASS (static)
echo -n "[TEST] Positive Reference Control: Valid boot log ... "
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

# 11. Positive Reference Control: Unmodified reference log must PASS (runtime)
echo -n "[TEST] Positive Reference Control: Valid runtime boot evidence ... "
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
