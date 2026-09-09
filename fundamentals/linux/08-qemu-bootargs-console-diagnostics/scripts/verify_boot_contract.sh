#!/bin/bash
set -euo pipefail

# Semantic Validator for P3-M04 QEMU Boot Configuration & Bootargs Contract
# Enforces:
# 1. Canonical machine flags: -machine virt,highmem=off,gic-version=2
# 2. CPU: -cpu cortex-a7
# 3. RAM: -m 512M
# 4. SMP: -smp 1
# 5. Display: -nographic
# 6. Kernel & Initrd: -kernel ... -initrd ...
# 7. Bootargs: earlycon=pl011,0x09000000, effective console=ttyAMA0,115200, rdinit=/init
# 8. Rejection of decoys in comments and conflicting console overrides.

CONFIG_FILE="${1:-}"

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Valid configuration or launch script file required: '$CONFIG_FILE'" >&2
    exit 1
fi

echo "=== Auditing QEMU Bootargs & Machine Contract: $CONFIG_FILE ==="

# Strip comment lines to ensure decoy comments don't satisfy checks
STRIPPED_CONTENT=$(grep -v '^[[:space:]]*#' "$CONFIG_FILE" || true)

if [ -z "$STRIPPED_CONTENT" ]; then
    echo "REJECT: Configuration file contains no active executable lines." >&2
    exit 2
fi

# 1. Check machine: virt
if ! echo "$STRIPPED_CONTENT" | grep -Eq '(-machine|--machine)[[:space:]=]+[^[:space:]]*virt'; then
    echo "REJECT: Missing canonical machine 'virt'." >&2
    exit 2
fi

# 2. Check highmem=off
if ! echo "$STRIPPED_CONTENT" | grep -Eq 'highmem=off'; then
    echo "REJECT: Missing required machine parameter 'highmem=off'." >&2
    exit 2
fi

# 3. Check gic-version=2
if ! echo "$STRIPPED_CONTENT" | grep -Eq 'gic-version=2'; then
    echo "REJECT: Missing required machine parameter 'gic-version=2'." >&2
    exit 2
fi

# 4. Check cpu: cortex-a7
if ! echo "$STRIPPED_CONTENT" | grep -Eq '(-cpu)[[:space:]=]+["'"'"']?cortex-a7["'"'"']?([[:space:]]|$)'; then
    echo "REJECT: Missing or invalid CPU parameter (must be cortex-a7)." >&2
    exit 2
fi

# 5. Check memory: 512M
if ! echo "$STRIPPED_CONTENT" | grep -Eq '(-m)[[:space:]=]+["'"'"']?512M["'"'"']?([[:space:]]|$)'; then
    echo "REJECT: Missing or invalid memory allocation (must be -m 512M)." >&2
    exit 2
fi

# 6. Check smp: 1
if ! echo "$STRIPPED_CONTENT" | grep -Eq '(-smp)[[:space:]=]+["'"'"']?1["'"'"']?([[:space:]]|$)'; then
    echo "REJECT: Missing or invalid SMP parameter (must be -smp 1)." >&2
    exit 2
fi

# 7. Check nographic
if ! echo "$STRIPPED_CONTENT" | grep -Eq '(-nographic)(["'"'"'[:space:]]|$)'; then
    echo "REJECT: Missing required flag '-nographic'." >&2
    exit 2
fi

# 8. Check bootargs / -append
if ! echo "$STRIPPED_CONTENT" | grep -Eq '(-append)'; then
    echo "REJECT: Missing -append parameter for kernel command line." >&2
    exit 2
fi

# Extract the -append argument
# Handle format: -append "..." or -append '...' or -append "$BOOTARGS"
# If BOOTARGS is set as a variable, resolve it from the active lines
APPEND_STR=""
if echo "$STRIPPED_CONTENT" | grep -Eq 'BOOTARGS='; then
    APPEND_STR=$(echo "$STRIPPED_CONTENT" | grep -E 'BOOTARGS=' | tail -n 1 | sed -E 's/^[[:space:]]*BOOTARGS=["'"'"']?([^"'"'"']+)["'"'"']?.*$/\1/')
fi
if [ -z "$APPEND_STR" ]; then
    APPEND_STR=$(echo "$STRIPPED_CONTENT" | grep -E '(-append)' | head -n 1 | sed -E 's/.*-append[[:space:]]+["'"'"']?([^"'"'"']+)["'"'"']?.*/\1/')
fi

# Check earlycon: earlycon=pl011,0x09000000
if ! echo "$APPEND_STR" | grep -Eq 'earlycon=pl011,0x09000000'; then
    echo "REJECT: Bootargs missing required earlycon contract: 'earlycon=pl011,0x09000000'." >&2
    exit 2
fi

# Check effective console:
# Linux kernel processes console= arguments left-to-right; the LAST valid console parameter becomes the primary console.
# We must find all console= tokens and verify the LAST one is ttyAMA0 (with optional baud rate).
CONSOLES=$(echo "$APPEND_STR" | grep -oE 'console=[^[:space:]]+' || true)
if [ -z "$CONSOLES" ]; then
    echo "REJECT: Bootargs missing 'console=' parameter." >&2
    exit 2
fi

LAST_CONSOLE=$(echo "$CONSOLES" | tail -n 1)
if ! echo "$LAST_CONSOLE" | grep -Eq '^console=ttyAMA0(,115200)?$'; then
    echo "REJECT: Effective console parameter is '$LAST_CONSOLE', expected 'console=ttyAMA0,115200'." >&2
    exit 2
fi

# Check rdinit=/init
if ! echo "$APPEND_STR" | grep -Eq 'rdinit=/init'; then
    echo "REJECT: Bootargs missing required init selector: 'rdinit=/init'." >&2
    exit 2
fi

echo "[PASS] QEMU machine flags, CPU, memory, and kernel bootargs contract fully VERIFIED."
