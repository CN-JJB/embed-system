#!/bin/bash
set -euo pipefail

# Reviewer-isolated fixture generator for P3-M03 Gate (REVIEWER-ONLY).
# Materializes an opaque defective rootfs for the full-assembly
# certification task plus the reviewer-only fixed reference. Learner
# workflows must never execute this script; the mapping below is hidden.

OUT_DIR="${1:-gate/fixtures}"
CROSS_COMPILE="${2:-arm-none-linux-gnueabihf-}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
REF_DIR="$M03_ROOT/reviewer/reference/gate_rootfs"

CC="${CROSS_COMPILE}gcc"
command -v "$CC" >/dev/null 2>&1 || { echo "ERROR: Cross compiler '$CC' not found." >&2; exit 1; }

mkdir -p "$OUT_DIR" "$REF_DIR"
WORK=$(mktemp -d /tmp/m03_gategen_XXXXXX)
trap 'rm -rf "$WORK"' EXIT

# 1. Build the SYNTHETIC teaching binary (labeled NOT BUSYBOX).
"$CC" -static -Wall -Werror -O2 "$M03_ROOT/fixtures/src/synthetic_multicall.c" -o "$WORK/synthetic_multicall"

# 2. Stage the known-good full-assembly tree.
GOOD="$WORK/good"
mkdir -p "$GOOD/bin" "$GOOD/sbin" "$GOOD/etc/init.d" "$GOOD/dev" \
         "$GOOD/proc" "$GOOD/sys" "$GOOD/tmp" "$GOOD/run" \
         "$GOOD/mnt" "$GOOD/root"
cp "$WORK/synthetic_multicall" "$GOOD/bin/synthetic_multicall"
chmod 755 "$GOOD/bin/synthetic_multicall"
ln -sf synthetic_multicall "$GOOD/bin/sh"
ln -sf synthetic_multicall "$GOOD/bin/ls"
ln -sf synthetic_multicall "$GOOD/bin/ps"
ln -sf synthetic_multicall "$GOOD/bin/mount"
ln -sf synthetic_multicall "$GOOD/bin/echo"
ln -sf synthetic_multicall "$GOOD/bin/cat"
ln -sf ../bin/synthetic_multicall "$GOOD/sbin/init"
# NOTE: $GOOD/init must be a real script file (NOT a symlink into bin/):
# writing through a symlinked init would follow the link and clobber the
# multicall binary on disk.
printf '#!/bin/sh\nmount -t proc none /proc\nmount -t sysfs none /sys\nmount -t devtmpfs none /dev 2>/dev/null || true\nexec /bin/sh\n' > "$GOOD/init"
chmod 755 "$GOOD/init"
printf '#!/bin/sh\nmount -t proc none /proc\nmount -t sysfs none /sys\nmount -t devtmpfs none /dev 2>/dev/null || true\n' > "$GOOD/etc/init.d/rcS"
chmod 755 "$GOOD/etc/init.d/rcS"
printf '%s\n' '::sysinit:/etc/init.d/rcS' 'ttyAMA0::askfirst:-/bin/sh' '::ctrlaltdel:/sbin/reboot' '::shutdown:/bin/umount -a -r' > "$GOOD/etc/inittab"

# 3. Publish the reviewer-only fixed reference.
rm -rf "$REF_DIR"
cp -a "$GOOD" "$REF_DIR"

# 4. Apply the hidden defective variant (rotated Round 1, distinct from
# the Challenge family).
# Constraint: do NOT seed missing-directory defects — git cannot store empty
# mount-point dirs, and learner provisioning scaffolds the FHS skeleton.
BAD="$WORK/bad"
cp -a "$GOOD" "$BAD"
# --- hidden defect set: encoded here only (reviewer-only) ---
ln -sf stale_target "$BAD/bin/sh"
printf '#!/bin/sh\necho "mount -t proc none /proc"\nmount -t sysfs none /sys\nmount -t devtmpfs none /dev 2>/dev/null || true\nexec /bin/sh\n' > "$BAD/init"
chmod 755 "$BAD/init"
# --- end hidden defect set ---

rm -rf "$OUT_DIR/defective_rootfs"
cp -a "$BAD" "$OUT_DIR/defective_rootfs"
echo "[GEN] M03 gate fixtures materialized in: $OUT_DIR/defective_rootfs"
echo "[GEN] Reviewer reference staged in: $REF_DIR"
