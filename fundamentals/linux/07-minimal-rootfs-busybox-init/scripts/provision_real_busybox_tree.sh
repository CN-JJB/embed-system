#!/bin/bash
set -euo pipefail

# Materialize a REAL BusyBox 1.36.1 rootfs WITHOUT the canonical init contract.
#
# Used to provision assessment trees: it installs the verified real BusyBox
# multi-call binary plus its genuine applet symlinks and the FHS skeleton, and
# nothing else. It never writes /etc/inittab or /etc/init.d/rcS: those are
# learner-authored artifacts, and a null rcS is left in place so the candidate
# is genuinely incomplete before the learner repairs it.
#
# The synthetic pedagogical fixture (fixtures/src/synthetic_multicall.c) is
# NEVER used here.
#
# Usage: provision_real_busybox_tree.sh <out-rootfs-dir>
#
# Environment:
#   BUSYBOX_STAGING : verified real BusyBox install tree from
#                     scripts/build_real_busybox.sh
#                     (default /tmp/rootfs-busybox-staging)

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

OUT="${1:-}"
if [ -z "$OUT" ]; then
    echo "ERROR: destination rootfs directory required." >&2
    exit 1
fi
case "$OUT" in
    /|.|..)
        echo "ERROR: refusing a dangerous destination: '$OUT'" >&2
        exit 1
        ;;
esac

BUSYBOX_STAGING="${BUSYBOX_STAGING:-/tmp/rootfs-busybox-staging}"

if [ ! -f "$BUSYBOX_STAGING/bin/busybox" ]; then
    echo "ERROR: verified real BusyBox staging not found at: $BUSYBOX_STAGING/bin/busybox" >&2
    echo "       Build it first (CROSS_COMPILE=<prefix>):" >&2
    echo "         bash $M03_ROOT/scripts/build_real_busybox.sh" >&2
    exit 1
fi
if ! bash "$M03_ROOT/scripts/audit_busybox_elf.sh" "$BUSYBOX_STAGING/bin/busybox" >/dev/null 2>&1; then
    echo "ERROR: $BUSYBOX_STAGING/bin/busybox is not a static ARM ELF BusyBox artifact." >&2
    exit 1
fi
BUSYBOX_STRINGS=$(strings -a "$BUSYBOX_STAGING/bin/busybox" 2>/dev/null || true)
if [[ "$BUSYBOX_STRINGS" != *"BusyBox v1.36.1"* ]]; then
    echo "ERROR: $BUSYBOX_STAGING/bin/busybox does not carry the BusyBox v1.36.1 identity." >&2
    exit 1
fi
if [[ "$BUSYBOX_STRINGS" == *"SYNTHETIC PEDAGOGICAL FIXTURE"* ]]; then
    echo "ERROR: staging contains the SYNTHETIC fixture, not real BusyBox." >&2
    exit 1
fi

echo "=== Provisioning REAL BusyBox tree (no init contract) ==="
echo "  source staging: $BUSYBOX_STAGING"
echo "  destination:    $OUT"

# Clear the destination CONTENTS rather than removing the directory inode: a
# caller may legitimately have $OUT as its own scratch cwd, and a vanished cwd
# breaks every later relative path in that shell.
mkdir -p "$OUT"
find "$OUT" -mindepth 1 -delete
cp -a "$BUSYBOX_STAGING/." "$OUT/"

mkdir -p "$OUT/dev" "$OUT/proc" "$OUT/sys" "$OUT/tmp" "$OUT/run" \
         "$OUT/mnt" "$OUT/root" "$OUT/etc/init.d"

# The verified staging places applets under bin/, sbin/, usr/bin/, usr/sbin/.
# Ensure the Phase 3 canonical applet locations exist for the core set.
for app in sh ls ps mount echo cat; do
    if [ ! -e "$OUT/bin/$app" ] && [ -e "$OUT/usr/bin/$app" ]; then
        ln -s busybox "$OUT/bin/$app"
    fi
done
if [ ! -e "$OUT/sbin/init" ]; then
    ln -s ../bin/busybox "$OUT/sbin/init"
fi

# Deterministic device-node metadata for reproducible packaging.
cp "$SCRIPT_DIR/canonical_devnodes.manifest" "$OUT/devnodes.manifest"

# Assemble a marker-bearing canonical /init shell script (Lab 3.4 path,
# rdinit=/init). This is the reference model, not the scored production path.
cat > "$OUT/init" << 'EOF'
#!/bin/sh
# Minimal shell PID 1 (rdinit=/init) mounting the kernel pseudo-filesystems.
# CONFIG_DEVTMPFS_MOUNT does not automount devtmpfs for initramfs boot, so
# userspace mounts /dev itself.
echo '=== REAL-BUSYBOX-INIT-START ==='
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true
echo '=== REAL-BUSYBOX-INIT-READY ==='
exec /bin/sh
EOF
chmod 755 "$OUT/init"

# Null starter rcS: deliberately unconfigured. The learner authors the
# production startup script; the defective provisioned fixtures overwrite
# this with their own state.
cat > "$OUT/etc/init.d/rcS" << 'EOF'
#!/bin/sh
# Production startup script (run by /sbin/init ::sysinit).
# TODO: bring up the system here.
echo '=== Embedded Linux System Initialized (real BusyBox) ==='
EOF
chmod 755 "$OUT/etc/init.d/rcS"

echo "[PASS] Real BusyBox tree provisioned at: $OUT ($(find "$OUT" -type l | wc -l) applet symlinks)"
