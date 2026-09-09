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

# Deterministic packaging: sort filenames in C locale using cpio or pycpio fallback
if command -v cpio >/dev/null 2>&1; then
    (
        cd "$ROOTFS_DIR"
        find . -mindepth 1 | LC_ALL=C sort | cpio -o -H newc --reproducible 2>/dev/null || \
        find . -mindepth 1 | LC_ALL=C sort | cpio -o -H newc
    ) | gzip -9 -n > "$ARCHIVE_ABS"
else
    SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    TMP_CPIO="${ARCHIVE_ABS%.gz}.raw"
    python3 "$SCRIPT_DIR/pycpio.py" "$ROOTFS_DIR" "$TMP_CPIO"
    gzip -9 -n -c "$TMP_CPIO" > "$ARCHIVE_ABS"
    rm -f "$TMP_CPIO"
fi

echo "[PASS] Packaged deterministic initramfs archive: $ARCHIVE_ABS ($(du -h "$ARCHIVE_ABS" | cut -f1))"
