#!/bin/bash
set -euo pipefail

# Semantic initramfs device-node auditor (M03).
# Validates char/block entries DIRECTLY from CPIO newc metadata
# (type, mode, major, minor) — never via unprivileged extraction alone.
# Usage: verify_initramfs_nodes.sh <archive.cpio.gz> [manifest]
# If manifest is omitted, the canonical scripts/canonical_devnodes.manifest
# contract (dev/console c 5 1 600, dev/null c 1 3 666) is enforced.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

ARCHIVE="${1:-}"
MANIFEST="${2:-$SCRIPT_DIR/canonical_devnodes.manifest}"

if [ -z "$ARCHIVE" ] || [ ! -f "$ARCHIVE" ]; then
    echo "ERROR: Valid initramfs archive required: '$ARCHIVE'" >&2
    exit 1
fi
if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: Device-node manifest not found: '$MANIFEST'" >&2
    exit 1
fi

TMP_CPIO=$(mktemp /tmp/m03_nodes_audit_XXXXXX.cpio)
trap 'rm -f "$TMP_CPIO"' EXIT
zcat "$ARCHIVE" > "$TMP_CPIO"

LISTING=$(python3 "$M03_ROOT/scripts/pycpio.py" --list "$TMP_CPIO")

FAIL=0
while read -r rel kind major minor mode; do
    [ -z "$rel" ] && continue
    case "$rel" in \#*) continue;; esac
    # manifest fields: <path> <c|b> <major> <minor> <mode>
    want_type="$kind"; want_maj="$major"; want_min="$minor"; want_mode="$mode"
    if [ "$want_type" = "c" ]; then want_label="char"; else want_label="block"; fi
    line=$(echo "$LISTING" | awk -v n="$rel" '$5==n' || true)
    if [ -z "$line" ]; then
        echo "REJECT: Device node '$rel' missing from initramfs archive metadata." >&2
        FAIL=1
        continue
    fi
    got_type=$(echo "$line" | awk '{print $1}')
    got_mode=$(echo "$line" | awk '{print $2}')
    got_rdev=$(echo "$line" | awk '{print $3}')
    got_maj="${got_rdev%%:*}"; got_min="${got_rdev##*:}"
    # Normalize octal (strip leading zeros for comparison).
    norm() { printf '%o' "$((8#$1))"; }
    if [ "$got_type" != "$want_label" ]; then
        echo "REJECT: Node '$rel' type is '$got_type', expected '$want_label'." >&2
        FAIL=1
    fi
    if [ "$(norm "$got_mode")" != "$(norm "$want_mode")" ]; then
        echo "REJECT: Node '$rel' mode is '$got_mode', expected '$want_mode'." >&2
        FAIL=1
    fi
    if [ "$got_maj" != "$want_maj" ] || [ "$got_min" != "$want_min" ]; then
        echo "REJECT: Node '$rel' rdev is '$got_maj:$got_min', expected '$want_maj:$want_min'." >&2
        FAIL=1
    fi
    echo "[PASS] Node $rel: type=$got_type mode=$got_mode rdev=$got_maj:$got_min"
done < "$MANIFEST"

if [ "$FAIL" -ne 0 ]; then
    exit 2
fi
echo "[PASS] Initramfs device-node contract verified against: $MANIFEST"
