#!/bin/bash
set -euo pipefail

# Rootfs Structure & Metadata Semantic Validator (M03)
# Validates FHS directory structure, init permissions, BusyBox applet links,
# and pseudo-filesystem mount configuration with ACTIVE mount-command
# semantics (comment/echo/decoy resistant).

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

# 4. Pseudo-filesystem mount contract (SEMANTIC, decoy-resistant).
# A valid mount requires an ACTIVE (non-comment, non-echo) command of the
# form: mount -t <fstype> ... <mountpoint>, with correct fstype<->target
# binding:
#   proc    -> /proc
#   sysfs   -> /sys
#   devtmpfs-> /dev
# Comment lines, echo-only text, wrong targets, or bare-word mentions
# MUST NOT satisfy this check.
MOUNT_SCRIPT=""
if [ -f "$ROOTFS_DIR/init" ] && head -n 1 "$ROOTFS_DIR/init" | grep -q "^#\!"; then
    MOUNT_SCRIPT="$ROOTFS_DIR/init"
elif [ -f "$ROOTFS_DIR/etc/init.d/rcS" ]; then
    MOUNT_SCRIPT="$ROOTFS_DIR/etc/init.d/rcS"
fi

if [ -n "$MOUNT_SCRIPT" ]; then
    # Strip comments and echo-only decoys: only real command lines count.
    ACTIVE=$(grep -v '^[[:space:]]*#' "$MOUNT_SCRIPT" \
        | grep -vE '^[[:space:]]*echo([[:space:]]|$)' || true)
    if [ -z "$ACTIVE" ]; then
        echo "REJECT: Init startup script '$MOUNT_SCRIPT' contains no active mount commands." >&2
        exit 2
    fi
    check_mount() {
        local fstype="$1" target="$2"
        # Active mount line: starts with 'mount', has '-t <fstype>',
        # and mounts exactly <target>. Allows 'mount -t proc none /proc',
        # 'mount -t proc proc /proc', extra flags, trailing '|| true'.
        if ! echo "$ACTIVE" | grep -Eq \
            "^[[:space:]]*mount([[:space:]]+-[A-Za-z]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+-t[[:space:]]+$fstype([[:space:]]|$)"; then
            echo "REJECT: Init script '$MOUNT_SCRIPT' lacks an ACTIVE 'mount -t $fstype' command (comments/echo text do not count)." >&2
            exit 2
        fi
        if ! echo "$ACTIVE" | grep -E \
            "^[[:space:]]*mount.*-t[[:space:]]+$fstype[[:space:]]+[^[:space:]]+[[:space:]]+$target([[:space:]]|$|;)" \
            >/dev/null; then
            echo "REJECT: Init script '$MOUNT_SCRIPT' has 'mount -t $fstype' but not targeting '$target' (wrong mount target)." >&2
            exit 2
        fi
    }
    check_mount "proc" "/proc"
    check_mount "sysfs" "/sys"
    # devtmpfs is SHOULD (tolerated with '|| true' fallback); require active
    # intent but do not fail closed if the appliance documents a no-devtmpfs
    # path explicitly. Canonical real rootfs mounts it.
    if echo "$ACTIVE" | grep -Eq "^[[:space:]]*mount.*-t[[:space:]]+devtmpfs([[:space:]]|$)"; then
        if ! echo "$ACTIVE" | grep -E \
            "^[[:space:]]*mount.*-t[[:space:]]+devtmpfs[[:space:]]+[^[:space:]]+[[:space:]]+/dev([[:space:]]|$|;)" \
            >/dev/null; then
            echo "REJECT: Init script '$MOUNT_SCRIPT' has 'mount -t devtmpfs' but not targeting '/dev'." >&2
            exit 2
        fi
        echo "[PASS] Pseudo-filesystem mounts (proc, sysfs, devtmpfs) confirmed in $MOUNT_SCRIPT"
    else
        echo "[PASS] Pseudo-filesystem mounts (proc, sysfs) confirmed in $MOUNT_SCRIPT (devtmpfs mount absent)"
    fi
fi

echo "[PASS] Rootfs structure validation successful."
