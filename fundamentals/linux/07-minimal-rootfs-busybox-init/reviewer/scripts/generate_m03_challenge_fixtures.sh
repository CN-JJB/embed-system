#!/bin/bash
set -euo pipefail

# Reviewer-isolated fixture generator for P3-M03 Challenge (REVIEWER-ONLY).
#
# Materializes (both gitignored, on demand from verified local staging):
#   <OUT_DIR>/defective_rootfs           defective REAL-BusyBox candidate
#   reviewer/reference/challenge_rootfs  reviewer-only fixed reference
#
# Both trees are built from the verified REAL BusyBox 1.36.1 staging artifact.
# The synthetic pedagogical fixture is NEVER used for scored assessment
# material. The assigned candidate state is the small opaque assignment
# input (challenge/fixtures/candidate.layer), instantiated via the
# learner-safe scripts/provision_challenge_candidate.sh so the reviewer
# defective is byte-identical to the learner provision output. The fixed
# reference is reviewer-only and is never tracked in Git.

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

# 3. Materialize the defective variant via the learner-safe provisioner so
# the reviewer defective is byte-identical to the learner workspace.
# Constraint: never damage /bin/busybox itself (the real artifact is not
# reparable by hand -- only applet wiring, permissions, and init
# configuration may be defective). The assigned candidate content lives in
# the small opaque assignment input, not in this generator.
rm -rf "$OUT_DIR/defective_rootfs"
bash "$M03_ROOT/scripts/provision_challenge_candidate.sh" "$OUT_DIR/defective_rootfs" >/dev/null

# 4. Audit both published trees for REAL BusyBox identity (static).
bash "$M03_ROOT/scripts/validate_real_busybox.sh" "$REF_DIR" >/dev/null
echo "[GEN] M03 challenge fixture materialized in: $OUT_DIR/defective_rootfs"
echo "[GEN] Reviewer reference staged in: $REF_DIR"
