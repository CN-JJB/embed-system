#!/bin/bash
set -euo pipefail

# Stage a REAL BusyBox 1.36.1 rootfs from a completed real build output.
# Usage: stage_real_rootfs.sh [REAL_STAGING] [ROOTFS_OUT]
#
# REAL_STAGING: output of scripts/build_real_busybox.sh
#   (default /tmp/rootfs-busybox-staging), containing real /bin/busybox
#   plus installed applet symlinks.
# ROOTFS_OUT: destination canonical real rootfs tree
#   (default <M03>/fixtures/build/real_rootfs).
#
# The script overlays the canonical Phase 3 init contract:
#   /init (shell PID 1 mounting proc/sys/dev, exec /bin/sh)
#   /etc/inittab + /etc/init.d/rcS (BusyBox /sbin/init production path)
#   FHS mount-point dirs, canonical devnodes.manifest (console/null)
# It never synthesizes BusyBox applets and never touches the synthetic
# pedagogical fixture.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

REAL_STAGING="${1:-${REAL_STAGING:-/tmp/rootfs-busybox-staging}}"
ROOTFS_OUT="${2:-$M03_ROOT/fixtures/build/real_rootfs}"

if [ ! -x "$REAL_STAGING/bin/busybox" ]; then
    echo "ERROR: Real BusyBox staging not found at: $REAL_STAGING/bin/busybox" >&2
    echo "Run first: CROSS_COMPILE=<prefix> bash $M03_ROOT/scripts/build_real_busybox.sh" >&2
    exit 1
fi
if [ ! -L "$REAL_STAGING/bin/sh" ]; then
    echo "ERROR: Real staging $REAL_STAGING/bin/sh missing or not a symlink." >&2
    exit 1
fi

echo "=== Staging REAL BusyBox rootfs ==="
echo "  source staging: $REAL_STAGING"
echo "  destination:    $ROOTFS_OUT"
rm -rf "$ROOTFS_OUT"
mkdir -p "$ROOTFS_OUT"
cp -a "$REAL_STAGING/." "$ROOTFS_OUT/"

mkdir -p "$ROOTFS_OUT/dev" "$ROOTFS_OUT/proc" "$ROOTFS_OUT/sys" \
         "$ROOTFS_OUT/tmp" "$ROOTFS_OUT/run" "$ROOTFS_OUT/mnt" \
         "$ROOTFS_OUT/root" "$ROOTFS_OUT/etc/init.d"

# Canonical /init: minimal shell PID 1 for rdinit=/init bring-up.
cat > "$ROOTFS_OUT/init" << 'EOF'
#!/bin/sh
# REAL BusyBox canonical PID 1 (rdinit=/init). Mounts kernel
# pseudo-filesystems manually: CONFIG_DEVTMPFS_MOUNT does NOT automount
# devtmpfs on initramfs boot (see drivers/base/Kconfig), so userspace
# must mount proc/sys/dev itself.
echo '=== REAL-BUSYBOX-INIT-START ==='
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true
echo '=== REAL-BUSYBOX-INIT-READY ==='
exec /bin/sh
EOF
chmod 755 "$ROOTFS_OUT/init"

# Production BusyBox init path (rdinit=/sbin/init).
cat > "$ROOTFS_OUT/etc/init.d/rcS" << 'EOF'
#!/bin/sh
# REAL BusyBox startup (run by /sbin/init ::sysinit).
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true
echo '=== Embedded Linux System Initialized (real BusyBox) ==='
EOF
chmod 755 "$ROOTFS_OUT/etc/init.d/rcS"

printf '%s\n' \
    '::sysinit:/etc/init.d/rcS' \
    'ttyAMA0::askfirst:-/bin/sh' \
    '::ctrlaltdel:/sbin/reboot' \
    '::shutdown:/bin/umount -a -r' \
    > "$ROOTFS_OUT/etc/inittab"

# Deterministic static device nodes (encoded by pycpio, no root needed).
cp "$SCRIPT_DIR/canonical_devnodes.manifest" "$ROOTFS_OUT/devnodes.manifest"

# Sanity: real BusyBox identity must survive staging.
if [ ! -L "$ROOTFS_OUT/bin/sh" ]; then
    echo "ERROR: $ROOTFS_OUT/bin/sh lost during staging." >&2
    exit 1
fi
if [ ! -L "$ROOTFS_OUT/sbin/init" ] && [ ! -x "$ROOTFS_OUT/sbin/init" ]; then
    echo "ERROR: $ROOTFS_OUT/sbin/init missing after staging." >&2
    exit 1
fi
echo "[PASS] Real BusyBox rootfs staged at: $ROOTFS_OUT"
