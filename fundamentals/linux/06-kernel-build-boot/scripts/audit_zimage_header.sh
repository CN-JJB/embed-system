#!/bin/bash
set -euo pipefail

# Production Validator for ARM zImage Boot Header
# Verifies ARM Linux boot magic 0x016f2818 at offset 0x24 and minimum length

ZIMAGE="${1:-}"

if [ -z "$ZIMAGE" ]; then
    echo "Usage: $0 <zImage_path>" >&2
    exit 1
fi

if [ ! -f "$ZIMAGE" ]; then
    echo "ERROR: zImage file does not exist: $ZIMAGE" >&2
    exit 1
fi

FILE_SIZE=$(wc -c < "$ZIMAGE")
if [ "$FILE_SIZE" -lt 40 ]; then
    echo "ERROR: zImage file is too short ($FILE_SIZE bytes < 40) to contain ARM boot header!" >&2
    exit 1
fi

ZMAGIC=$(hexdump -s 0x24 -n 4 -e '"%08x"' "$ZIMAGE" 2>/dev/null || true)
if [ "$ZMAGIC" != "016f2818" ]; then
    echo "ERROR: Invalid ARM zImage magic (got 0x${ZMAGIC:-empty}, expected 0x016f2818 at offset 0x24)!" >&2
    exit 1
fi

echo "[PASS] ARM zImage header verified (Magic: 0x016f2818 at offset 0x24, Size: $FILE_SIZE bytes)"
exit 0
