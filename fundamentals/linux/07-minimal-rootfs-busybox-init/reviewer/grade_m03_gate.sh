#!/bin/bash
set -euo pipefail

# Reviewer Grading Oracle for P3-M03 Gate
# Verifies rootfs archive integrity, static ARM ELF linkage, permissions,
# applet symlinks, and pseudo-filesystem mount configuration.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

ARCHIVE="${1:-$M03_ROOT/gate/build/rootfs_gate.cpio.gz}"
if [ ! -f "$ARCHIVE" ]; then
    echo "REJECT: Gate archive '$ARCHIVE' does not exist." >&2
    exit 2
fi

TMP_DIR=$(mktemp -d /tmp/m03_gate_unpack_XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

# Unpack archive
if command -v cpio >/dev/null 2>&1; then
    (
        cd "$TMP_DIR"
        zcat "$ARCHIVE" | cpio -idm --quiet 2>/dev/null || zcat "$ARCHIVE" | cpio -idm 2>/dev/null
    )
else
    RAW_CPIO="$TMP_DIR/archive.raw"
    zcat "$ARCHIVE" > "$RAW_CPIO"
    python3 "$M03_ROOT/scripts/pycpio.py" --extract "$RAW_CPIO" "$TMP_DIR"
    rm -f "$RAW_CPIO"
fi

# 1. Audit Rootfs Structure
bash "$M03_ROOT/scripts/verify_rootfs_structure.sh" "$TMP_DIR"

# 2. Audit BusyBox ELF
BUSYBOX_BIN="$TMP_DIR/bin/busybox"
if [ ! -f "$BUSYBOX_BIN" ]; then
    echo "REJECT: /bin/busybox missing from unpacked rootfs." >&2
    exit 2
fi
bash "$M03_ROOT/scripts/audit_busybox_elf.sh" "$BUSYBOX_BIN"

# 3. Audit Init Executable
INIT_BIN="$TMP_DIR/init"
[ -f "$INIT_BIN" ] || INIT_BIN="$TMP_DIR/sbin/init"
if [ ! -x "$INIT_BIN" ]; then
    echo "REJECT: Init binary '$INIT_BIN' is not executable." >&2
    exit 2
fi

echo "[PASS] P3-M03 Gate Submission: VERIFIED (100/100)"
