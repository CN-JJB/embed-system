#!/bin/bash
set -euo pipefail

# Reviewer-isolated fixture generator for P3-M03 Challenge (REVIEWER-ONLY).
# Materializes an opaque defective rootfs for the production-BusyBox-init
# task plus the reviewer-only fixed reference. Learner workflows must never
# execute this script; the mapping below is the hidden assessment contract.

OUT_DIR="${1:-challenge/fixtures}"
CROSS_COMPILE="${2:-arm-none-linux-gnueabihf-}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
REF_DIR="$M03_ROOT/reviewer/reference/challenge_rootfs"

CC="${CROSS_COMPILE}gcc"
command -v "$CC" >/dev/null 2>&1 || { echo "ERROR: Cross compiler '$CC' not found." >&2; exit 1; }

mkdir -p "$OUT_DIR" "$REF_DIR"
WORK=$(mktemp -d /tmp/m03_chgen_XXXXXX)
trap 'rm -rf "$WORK"' EXIT

# 1. Build the SYNTHETIC teaching binary (labeled NOT BUSYBOX).
"$CC" -static -Wall -Werror -O2 "$M03_ROOT/fixtures/src/synthetic_multicall.c" -o "$WORK/synthetic_multicall"

# 2. Stage the known-good production-init tree.
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
ln -sf bin/synthetic_multicall "$GOOD/init"
printf '#!/bin/sh\nmount -t proc none /proc\nmount -t sysfs none /sys\nmount -t devtmpfs none /dev 2>/dev/null || true\n' > "$GOOD/etc/init.d/rcS"
chmod 755 "$GOOD/etc/init.d/rcS"
printf '%s\n' '::sysinit:/etc/init.d/rcS' 'ttyAMA0::askfirst:-/bin/sh' '::ctrlaltdel:/sbin/reboot' '::shutdown:/bin/umount -a -r' > "$GOOD/etc/inittab"

# 3. Publish the reviewer-only fixed reference.
rm -rf "$REF_DIR"
cp -a "$GOOD" "$REF_DIR"

# 4. Apply the hidden defective variant (rotated Round 1).
# Constraint: do NOT seed missing-directory defects — git cannot store empty
# mount-point dirs, and learner provisioning scaffolds the FHS skeleton.
BAD="$WORK/bad"
cp -a "$GOOD" "$BAD"
# --- hidden defect set: encoded here only (reviewer-only) ---
chmod 644 "$BAD/etc/init.d/rcS"
rm -f "$BAD/bin/ps"
printf '%s\n' '::sysinit:/etc/init.d/rcS' 'console::askfirst:-/bin/sh' '::ctrlaltdel:/sbin/reboot' '::shutdown:/bin/umount -a -r' > "$BAD/etc/inittab"
printf '#!/bin/sh\n# startup mounts documented below (not yet active)\n# mount -t proc none /proc\nmount -t sysfs none /sys\nmount -t devtmpfs none /dev 2>/dev/null || true\n' > "$BAD/etc/init.d/rcS"
# --- end hidden defect set ---

rm -rf "$OUT_DIR/defective_rootfs"
cp -a "$BAD" "$OUT_DIR/defective_rootfs"
echo "[GEN] M03 challenge fixtures materialized in: $OUT_DIR/defective_rootfs"
echo "[GEN] Reviewer reference staged in: $REF_DIR"
