#!/bin/bash
set -euo pipefail

# Deterministic Initramfs CPIO Archive Packager (M03)
# Produces a reproducible cpio.gz in newc format with normalized sorting.

ROOTFS_DIR="${1:-}"
OUTPUT_ARCHIVE="${2:-}"

if [ -z "$ROOTFS_DIR" ] || [ ! -d "$ROOTFS_DIR" ]; then
    echo "ERROR: Valid rootfs directory required: '$ROOTFS_DIR'" >&2
    exit 1
fi

if [ -z "$OUTPUT_ARCHIVE" ]; then
    echo "ERROR: Output archive path required" >&2
    exit 1
fi

# Audit minimal init contract before packaging
if [ ! -f "$ROOTFS_DIR/init" ] && [ ! -f "$ROOTFS_DIR/sbin/init" ]; then
    echo "REJECT: Neither '/init' nor '/sbin/init' found in rootfs staging directory: $ROOTFS_DIR" >&2
    exit 2
fi

INIT_FILE="$ROOTFS_DIR/init"
[ -f "$INIT_FILE" ] || INIT_FILE="$ROOTFS_DIR/sbin/init"

if [ ! -x "$INIT_FILE" ]; then
    echo "REJECT: Init executable '$INIT_FILE' lacks executable permission (+x)." >&2
    exit 2
fi

mkdir -p "$(dirname "$OUTPUT_ARCHIVE")"
ARCHIVE_ABS=$(cd "$(dirname "$OUTPUT_ARCHIVE")" && pwd)/$(basename "$OUTPUT_ARCHIVE")
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Hermetic deterministic packaging via pycpio.py (newc): sorted entries,
# UID/GID 0, mtime 0, gzip -n. Host cpio is deliberately NOT used here:
# its mtime handling is host-dependent (nondeterministic rebuild churn),
# while pycpio is byte-reproducible. A device-node manifest
# (devnodes.manifest) is consumed automatically when present.
TMP_CPIO="${ARCHIVE_ABS%.gz}.raw"
python3 "$SCRIPT_DIR/pycpio.py" "$ROOTFS_DIR" "$TMP_CPIO"
gzip -9 -n -c "$TMP_CPIO" > "$ARCHIVE_ABS"
rm -f "$TMP_CPIO"

echo "[PASS] Packaged deterministic initramfs archive: $ARCHIVE_ABS ($(du -h "$ARCHIVE_ABS" | cut -f1))"
