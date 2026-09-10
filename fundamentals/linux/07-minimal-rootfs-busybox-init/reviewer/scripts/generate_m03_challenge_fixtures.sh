#!/bin/bash
set -euo pipefail

# Reviewer-isolated fixture generator for P3-M03 Challenge (REVIEWER-ONLY).
#
# Materializes:
#   <OUT_DIR>/defective_rootfs     opaque defective REAL-BusyBox tree
#   reviewer/reference/challenge_rootfs   reviewer-only fixed reference
#
# Both trees are built from the verified REAL BusyBox 1.36.1 staging artifact
# (scripts/provision_real_busybox_tree.sh). The synthetic pedagogical fixture
# is NEVER used for scored assessment material. The hidden defect set is
# encoded only here and must never reach learner-facing material.

OUT_DIR="${1:-challenge/fixtures}"
CROSS_COMPILE="${2:-arm-none-linux-gnueabihf-}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
REF_DIR="$M03_ROOT/reviewer/reference/challenge_rootfs"

CC="${CROSS_COMPILE}gcc"
command -v "$CC" >/dev/null 2>&1 || { echo "ERROR: Cross compiler '$CC' not found." >&2; exit 1; }

mkdir -p "$OUT_DIR" "$REF_DIR"
# NOTE: delete the scratch tree's CONTENTS, never the scratch directory inode
# itself. scripts/provision_real_busybox_tree.sh chdirs into its destination
# while installing, so removing the directory (rather than its contents) makes
# the shell's cwd vanish for the remainder of the trap and breaks the exit.
WORK=$(mktemp -d /tmp/m03_chgen_XXXXXX)
trap 'find "$WORK" -mindepth 1 -delete 2>/dev/null || true' EXIT

# 0. Component-test fixture only (fast synthetic multicall): never scored.
"$CC" -static -Wall -Werror -O2 "$M03_ROOT/fixtures/src/synthetic_multicall.c" \
    -o "$WORK/synthetic_multicall"

# 1. Stage the known-good REAL BusyBox full assembly.
GOOD="$WORK/good"
bash "$M03_ROOT/scripts/provision_real_busybox_tree.sh" "$GOOD" >/dev/null
cat > "$GOOD/etc/init.d/rcS" << 'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true
echo '=== Embedded Linux System Initialized (real BusyBox) ==='
EOF
chmod 755 "$GOOD/etc/init.d/rcS"
printf '%s\n' \
    '::sysinit:/etc/init.d/rcS' \
    'ttyAMA0::askfirst:-/bin/sh' \
    '::ctrlaltdel:/sbin/reboot' \
    '::shutdown:/bin/umount -a -r' \
    > "$GOOD/etc/inittab"

# 2. Publish the reviewer-only fixed reference.
rm -rf "$REF_DIR"
cp -a "$GOOD" "$REF_DIR"

# 3. Apply the hidden defective variant (rotated Round 2; distinct from the
# Gate family). Constraint: never seed missing directories (git cannot store
# empty mount-point dirs and provisioning scaffolds the FHS skeleton), and
# never damage /bin/busybox itself (the real artifact is not reparaphraseable
# by hand -- only applet wiring, permissions, and init configuration may be
# defective).
BAD="$WORK/bad"
cp -a "$GOOD" "$BAD"
# --- hidden defect set: encoded here only (reviewer-only) ---
ln -sf stale_target "$BAD/bin/ls"
chmod 644 "$BAD/etc/init.d/rcS"
printf '%s\n' \
    '::sysinit:/etc/init.d/rcS' \
    'console::askfirst:-/bin/sh' \
    '::ctrlaltdel:/sbin/reboot' \
    '::shutdown:/bin/umount -a -r' \
    > "$BAD/etc/inittab"
printf '#!/bin/sh\n# startup mounts documented below (not yet active)\n# mount -t proc none /proc\nmount -t sysfs none /sys\nmount -t devtmpfs none /dev 2>/dev/null || true\n' \
    > "$BAD/etc/init.d/rcS"
chmod 644 "$BAD/etc/init.d/rcS"
# --- end hidden defect set ---

rm -rf "$OUT_DIR/defective_rootfs"
cp -a "$BAD" "$OUT_DIR/defective_rootfs"

# 4. Audit both published trees for REAL BusyBox identity (static).
bash "$M03_ROOT/scripts/validate_real_busybox.sh" "$REF_DIR" >/dev/null
echo "[GEN] M03 challenge fixture materialized in: $OUT_DIR/defective_rootfs"
echo "[GEN] Reviewer reference staged in: $REF_DIR"
