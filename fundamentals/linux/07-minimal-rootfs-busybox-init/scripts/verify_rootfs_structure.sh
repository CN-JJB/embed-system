#!/bin/bash
set -euo pipefail

# Rootfs Structure & Metadata Semantic Validator (M03)
# Validates FHS directory structure, init permissions, BusyBox applet links,
# and pseudo-filesystem mount configuration.

ROOTFS_DIR="${1:-}"
if [ -z "$ROOTFS_DIR" ] || [ ! -d "$ROOTFS_DIR" ]; then
    echo "ERROR: Valid rootfs directory required: '$ROOTFS_DIR'" >&2
    exit 1
fi

echo "=== Auditing Rootfs Structure: $ROOTFS_DIR ==="

# 1. Essential FHS Directories
REQUIRED_DIRS=(bin sbin etc dev proc sys tmp run mnt root)
for d in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$ROOTFS_DIR/$d" ]; then
        echo "REJECT: Required directory '$d' missing in rootfs layout." >&2
        exit 2
    fi
done
echo "[PASS] Essential FHS directories present: ${REQUIRED_DIRS[*]}"

# 2. Init Executable
if [ ! -f "$ROOTFS_DIR/init" ] && [ ! -f "$ROOTFS_DIR/sbin/init" ]; then
    echo "REJECT: Neither '/init' nor '/sbin/init' exists in rootfs." >&2
    exit 2
fi

INIT_PATH="$ROOTFS_DIR/init"
[ -f "$INIT_PATH" ] || INIT_PATH="$ROOTFS_DIR/sbin/init"

if [ ! -x "$INIT_PATH" ]; then
    echo "REJECT: Init candidate '$INIT_PATH' is missing executable permission (+x)." >&2
    exit 2
fi
echo "[PASS] Working init executable confirmed: $INIT_PATH (Mode: $(stat -c '%a' "$INIT_PATH" 2>/dev/null || stat -f '%Lp' "$INIT_PATH"))"

# 3. BusyBox or Shell Presence & Symlinks
if [ ! -f "$ROOTFS_DIR/bin/sh" ]; then
    echo "REJECT: Essential shell '/bin/sh' missing." >&2
    exit 2
fi

if [ -L "$ROOTFS_DIR/bin/sh" ]; then
    SH_TARGET=$(readlink "$ROOTFS_DIR/bin/sh")
    # Must resolve within rootfs
    if [ ! -f "$ROOTFS_DIR/bin/$SH_TARGET" ] && [ ! -f "$ROOTFS_DIR/$SH_TARGET" ]; then
        echo "REJECT: Broken symlink for /bin/sh -> '$SH_TARGET'" >&2
        exit 2
    fi
    echo "[PASS] /bin/sh valid symlink: -> $SH_TARGET"
else
    echo "[PASS] /bin/sh binary executable present"
fi

# 4. Pseudo-filesystem mount contract
# If /init or /etc/init.d/rcS is a script, inspect mount commands
MOUNT_SCRIPT=""
if [ -f "$ROOTFS_DIR/init" ] && head -n 1 "$ROOTFS_DIR/init" | grep -q "^#\!"; then
    MOUNT_SCRIPT="$ROOTFS_DIR/init"
elif [ -f "$ROOTFS_DIR/etc/init.d/rcS" ]; then
    MOUNT_SCRIPT="$ROOTFS_DIR/etc/init.d/rcS"
fi

if [ -n "$MOUNT_SCRIPT" ]; then
    if ! grep -q "proc" "$MOUNT_SCRIPT"; then
        echo "REJECT: Init startup script '$MOUNT_SCRIPT' does not contain 'proc' filesystem mount." >&2
        exit 2
    fi
    if ! grep -q "sysfs" "$MOUNT_SCRIPT"; then
        echo "REJECT: Init startup script '$MOUNT_SCRIPT' does not contain 'sysfs' filesystem mount." >&2
        exit 2
    fi
    echo "[PASS] Pseudo-filesystem mounts (proc, sysfs) confirmed in $MOUNT_SCRIPT"
fi

echo "[PASS] Rootfs structure validation successful."
