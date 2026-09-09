#!/bin/bash
set -euo pipefail

# Adversarial Mutation Test Suite for P3-M03 Validators & Grading Oracle
# Verifies that every defect class is semantically REJECTED (not crashed).

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

echo "================================================================"
echo "=== Running P3-M03 Adversarial Mutation Suite                ==="
echo "================================================================"

WORK_DIR=$(mktemp -d /tmp/m03_mutations_XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

VALID_DIR="$M03_ROOT/fixtures/build/rootfs"
[ -d "$VALID_DIR" ] || {
    make -C "$M03_ROOT/fixtures" all CROSS_COMPILE="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}" >/dev/null
}

MUTATION_COUNT=0
PASS_COUNT=0

assert_rejected() {
    local name="$1"
    local dir="$2"
    MUTATION_COUNT=$((MUTATION_COUNT + 1))
    echo -n "[TEST] Mutation $MUTATION_COUNT: $name ... "

    set +e
    OUTPUT=$(bash "$M03_ROOT/scripts/verify_rootfs_structure.sh" "$dir" 2>&1)
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

assert_elf_rejected() {
    local name="$1"
    local file="$2"
    MUTATION_COUNT=$((MUTATION_COUNT + 1))
    echo -n "[TEST] Mutation $MUTATION_COUNT: $name ... "

    set +e
    OUTPUT=$(bash "$M03_ROOT/scripts/audit_busybox_elf.sh" "$file" 2>&1)
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

# 1. Mutation: Missing executable permission on /init
MUT1="$WORK_DIR/mut1_noexec"
cp -r "$VALID_DIR" "$MUT1"
chmod -x "$MUT1/init"
[ -f "$MUT1/sbin/init" ] && chmod -x "$MUT1/sbin/init" || true
assert_rejected "Missing executable permission on init" "$MUT1"

# 2. Mutation: Broken symlink for /bin/sh
MUT2="$WORK_DIR/mut2_brokencmd"
cp -r "$VALID_DIR" "$MUT2"
ln -sf "nonexistent_target" "$MUT2/bin/sh"
assert_rejected "Broken symlink for /bin/sh" "$MUT2"

# 3. Mutation: Missing essential FHS directory (/dev)
MUT3="$WORK_DIR/mut3_missingdir"
cp -r "$VALID_DIR" "$MUT3"
rm -rf "$MUT3/dev"
assert_rejected "Missing required directory /dev" "$MUT3"

# 4. Mutation: Init script missing procfs mount
MUT4="$WORK_DIR/mut4_noproc"
cp -r "$VALID_DIR" "$MUT4"
echo "#!/bin/sh" > "$MUT4/etc/init.d/rcS"
echo "echo 'Hello world without proc'" >> "$MUT4/etc/init.d/rcS"
chmod 755 "$MUT4/etc/init.d/rcS"
assert_rejected "Init script missing procfs mount" "$MUT4"

# 5. Mutation: Host x86_64 ELF binary masquerading as ARM
MUT5_BIN="$WORK_DIR/host_x86_bin"
gcc -O2 -o "$MUT5_BIN" -x c - << 'EOF'
int main() { return 0; }
EOF
assert_elf_rejected "Host non-ARM ELF binary" "$MUT5_BIN"

# 6. Mutation: Dynamically linked ELF binary masquerading as static
MUT6_BIN="$WORK_DIR/dynamic_arm_bin"
CROSS_CC="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}gcc"
if command -v "$CROSS_CC" >/dev/null 2>&1; then
    "$CROSS_CC" -O2 -o "$MUT6_BIN" -x c - << 'EOF'
#include <stdio.h>
int main() { printf("dynamic\n"); return 0; }
EOF
    assert_elf_rejected "Dynamically linked ARM binary" "$MUT6_BIN"
fi

# 7. Positive Reference Control: Unmodified reference must PASS
echo -n "[TEST] Positive Reference Control: Valid rootfs ... "
set +e
REF_OUTPUT=$(bash "$M03_ROOT/scripts/verify_rootfs_structure.sh" "$VALID_DIR" 2>&1)
REF_RC=$?
set -e
if [ $REF_RC -eq 0 ] && echo "$REF_OUTPUT" | grep -q "Rootfs structure validation successful"; then
    echo "PASS"
else
    echo "FAIL (Valid reference failed to pass!)"
    echo "$REF_OUTPUT"
    exit 1
fi

echo "================================================================"
echo "=== ALL $PASS_COUNT P3-M03 MUTATION & REFERENCE CHECKS PASSED ==="
echo "================================================================"
