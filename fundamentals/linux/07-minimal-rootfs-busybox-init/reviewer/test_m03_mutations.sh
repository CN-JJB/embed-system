#!/bin/bash
set -euo pipefail

# Adversarial Mutation Test Suite for P3-M03 Validators & Grading Oracle
# Verifies that every defect class is semantically REJECTED (not crashed).
# Covers: init permissions, applet symlinks, FHS layout, ACTIVE mount
# semantics (comment/echo decoys, wrong targets), ELF identity, and
# initramfs device-node metadata (type/mode/major/minor).

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

echo "================================================================"
echo "=== Running P3-M03 Adversarial Mutation Suite                ==="
echo "================================================================"

WORK_DIR=$(mktemp -d /tmp/m03_mutations_XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

# SYNTHETIC teaching rootfs (NOT BUSYBOX) is the component-validator
# reference. Real BusyBox archives are graded by the reviewer oracle.
VALID_DIR="$M03_ROOT/fixtures/build/synthetic_rootfs"
[ -d "$VALID_DIR" ] || {
    make -C "$M03_ROOT/fixtures" synthetic CROSS_COMPILE="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}" >/dev/null
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

assert_nodes_rejected() {
    local name="$1"
    local archive="$2"
    MUTATION_COUNT=$((MUTATION_COUNT + 1))
    echo -n "[TEST] Mutation $MUTATION_COUNT: $name ... "

    set +e
    OUTPUT=$(bash "$M03_ROOT/scripts/verify_initramfs_nodes.sh" "$archive" 2>&1)
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

# Valid reference must grade via /init script path: neutralize rcS so that
# mount mutations apply to the graded script deterministically.
# The synthetic fixture stages /init as a symlink; for mutation purposes we
# materialize a real /init script twin of rcS content.
prep_graded_init() {
    local dir="$1"
    if [ -L "$dir/init" ]; then
        rm -f "$dir/init"
        printf '#!/bin/sh\nmount -t proc none /proc\nmount -t sysfs none /sys\nmount -t devtmpfs none /dev 2>/dev/null || true\nexec /bin/sh\n' > "$dir/init"
        chmod 755 "$dir/init"
    fi
}

# 1. Mutation: Missing executable permission on /init
MUT1="$WORK_DIR/mut1_noexec"
cp -r "$VALID_DIR" "$MUT1"
prep_graded_init "$MUT1"
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

# 4. Mutation: Init script missing procfs mount (plain omission)
MUT4="$WORK_DIR/mut4_noproc"
cp -r "$VALID_DIR" "$MUT4"
prep_graded_init "$MUT4"
printf '#!/bin/sh\nmount -t sysfs none /sys\nmount -t devtmpfs none /dev 2>/dev/null || true\nexec /bin/sh\n' > "$MUT4/init"
chmod 755 "$MUT4/init"
assert_rejected "Init script missing procfs mount" "$MUT4"

# 5. Mutation: proc decoy — comment + echo mention proc, but no ACTIVE
# mount -t proc command (valid sysfs/devtmpfs present). Must REJECT.
MUT5D="$WORK_DIR/mut5_proc_decoy"
cp -r "$VALID_DIR" "$MUT5D"
prep_graded_init "$MUT5D"
printf '#!/bin/sh\n# mount -t proc none /proc (documented but not executed)\necho "mount -t proc none /proc"\nmount -t sysfs none /sys\nmount -t devtmpfs none /dev 2>/dev/null || true\nexec /bin/sh\n' > "$MUT5D/init"
chmod 755 "$MUT5D/init"
assert_rejected "proc comment/echo decoy without active mount" "$MUT5D"

# 6. Mutation: sysfs decoy — comment + echo mention sysfs, but no ACTIVE
# mount -t sysfs command (valid proc/devtmpfs present). Must REJECT.
MUT6D="$WORK_DIR/mut6_sysfs_decoy"
cp -r "$VALID_DIR" "$MUT6D"
prep_graded_init "$MUT6D"
printf '#!/bin/sh\nmount -t proc none /proc\n# mount -t sysfs none /sys\necho "mount -t sysfs none /sys"\nmount -t devtmpfs none /dev 2>/dev/null || true\nexec /bin/sh\n' > "$MUT6D/init"
chmod 755 "$MUT6D/init"
assert_rejected "sysfs comment/echo decoy without active mount" "$MUT6D"

# 7. Mutation: wrong mount target — 'mount -t proc' targeting /mnt.
# Must REJECT (fstype present, binding wrong).
MUT7W="$WORK_DIR/mut7_wrong_target"
cp -r "$VALID_DIR" "$MUT7W"
prep_graded_init "$MUT7W"
printf '#!/bin/sh\nmount -t proc none /mnt\nmount -t sysfs none /sys\nmount -t devtmpfs none /dev 2>/dev/null || true\nexec /bin/sh\n' > "$MUT7W/init"
chmod 755 "$MUT7W/init"
assert_rejected "proc mount bound to wrong target /mnt" "$MUT7W"

# 8. Mutation: Host x86_64 ELF binary masquerading as ARM
MUT8_BIN="$WORK_DIR/host_x86_bin"
gcc -O2 -o "$MUT8_BIN" -x c - << 'EOF'
int main() { return 0; }
EOF
assert_elf_rejected "Host non-ARM ELF binary" "$MUT8_BIN"

# 9. Mutation: Dynamically linked ELF binary masquerading as static
MUT9_BIN="$WORK_DIR/dynamic_arm_bin"
CROSS_CC="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}gcc"
if command -v "$CROSS_CC" >/dev/null 2>&1; then
    "$CROSS_CC" -O2 -o "$MUT9_BIN" -x c - << 'EOF'
#include <stdio.h>
int main() { printf("dynamic\n"); return 0; }
EOF
    assert_elf_rejected "Dynamically linked ARM binary" "$MUT9_BIN"
fi

# 10-12. Device-node metadata mutations (archive-level, semantic).
# Build a minimal staging with a manifest, package, then mutate the
# manifest contract: wrong type / wrong major:minor.
if command -v gzip >/dev/null 2>&1; then
    NODE_STAGE="$WORK_DIR/nodestage"
    mkdir -p "$NODE_STAGE/dev" "$NODE_STAGE/proc" "$NODE_STAGE/sys" \
             "$NODE_STAGE/bin" "$NODE_STAGE/sbin" "$NODE_STAGE/etc" \
             "$NODE_STAGE/tmp" "$NODE_STAGE/run" "$NODE_STAGE/mnt" \
             "$NODE_STAGE/root"
    printf '#!/bin/sh\nexec /bin/sh\n' > "$NODE_STAGE/init"
    chmod 755 "$NODE_STAGE/init"
    printf 'dev/console c 5 1 600\ndev/null c 1 3 666\n' > "$NODE_STAGE/devnodes.manifest"
    NODE_GOOD="$WORK_DIR/nodes_good.cpio.gz"
    bash "$M03_ROOT/scripts/package_initramfs.sh" "$NODE_STAGE" "$NODE_GOOD" >/dev/null
    # Wrong major:minor for /dev/console (5:2 instead of 5:1).
    printf 'dev/console c 5 2 600\ndev/null c 1 3 666\n' > "$WORK_DIR/wrong_major.manifest"
    MUT10="$WORK_DIR/mut10_node_major"
    cp "$NODE_GOOD" "$MUT10.cpio.gz"
    # Grade the good archive against the WRONG manifest -> must REJECT.
    MUTATION_COUNT=$((MUTATION_COUNT + 1))
    echo -n "[TEST] Mutation $MUTATION_COUNT: device node wrong major:minor ... "
    set +e
    OUTPUT=$(bash "$M03_ROOT/scripts/verify_initramfs_nodes.sh" "$MUT10.cpio.gz" "$WORK_DIR/wrong_major.manifest" 2>&1)
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
    # Missing /dev/null line in contract -> archive has extra node; grade
    # a manifest that omits it is a PASS (subset), so instead drop the node
    # from the archive and grade against the full manifest -> REJECT.
    NODE_STAGE2="$WORK_DIR/nodestage2"
    cp -a "$NODE_STAGE" "$NODE_STAGE2"
    printf 'dev/console c 5 1 600\n' > "$NODE_STAGE2/devnodes.manifest"
    NODE_MISSING="$WORK_DIR/nodes_missing_null.cpio.gz"
    bash "$M03_ROOT/scripts/package_initramfs.sh" "$NODE_STAGE2" "$NODE_MISSING" >/dev/null
    assert_nodes_rejected "device node /dev/null missing from archive" "$NODE_MISSING"
fi

# Positive Reference Control: Unmodified reference must PASS
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
