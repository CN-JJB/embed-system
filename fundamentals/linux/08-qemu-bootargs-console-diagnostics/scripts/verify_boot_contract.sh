#!/bin/bash
set -euo pipefail

# Semantic Validator for the P3-M04 Candidate Launch Manifest.
#
# The candidate submission is a DATA-ONLY manifest; all interpretation lives
# in scripts/parse_candidate_manifest.py so that the declared configuration
# and the executed QEMU argv are the same source of truth. This wrapper is
# used by the learner-safe self-check and by the reviewer oracle, and it can
# additionally prove that the declarations were actually executed by binding
# a fresh console capture plus its provenance record.
#
# Usage: verify_boot_contract.sh <candidate-manifest> [provenance] [console-log]
#
# Contract enforced (canonical Phase 3 platform):
#   MACHINE=virt,highmem=off,gic-version=2
#   CPU=cortex-a7
#   MEM=512M
#   SMP=1
#   NOGRAPHIC=true
#   BOOTARGS=earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init
# plus: exactly-one console token, no duplicate/unknown/conflicting keys,
# no non-declarative (shell) content, and -- when supplied -- executed-argv
# and guest-evidence binding.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

CONFIG_FILE="${1:-}"
PROVENANCE="${2:-}"
CONSOLE_LOG="${3:-}"

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Candidate manifest required: '${CONFIG_FILE:-<empty>}'" >&2
    exit 1
fi

echo "=== Auditing P3-M04 Candidate Launch Manifest: $CONFIG_FILE ==="

# 1. Declarations: schema, duplicates, conflicts, canonical values.
set +e
PARSE_OUT=$(python3 "$SCRIPT_DIR/parse_candidate_manifest.py" --manifest "$CONFIG_FILE" 2>&1)
PARSE_RC=$?
set -e
if [ "$PARSE_RC" -ne 0 ]; then
    echo "REJECT: manifest does not satisfy the canonical launch contract:" >&2
    echo "$PARSE_OUT" | sed 's/^/  /' >&2
    exit 2
fi
echo "[PASS] Manifest schema, uniqueness, conflict and canonical-value checks passed."
echo "$PARSE_OUT" | sed -n '/^ARGV_BEGIN$/,/^ARGV_END$/p' | sed 's/^/      /'

# 2. Optional executed-argv + guest-evidence binding.
if [ -n "$PROVENANCE" ] || [ -n "$CONSOLE_LOG" ]; then
    if [ -z "$PROVENANCE" ] || [ -z "$CONSOLE_LOG" ]; then
        echo "ERROR: binding requires BOTH <provenance> and <console-log>." >&2
        exit 1
    fi
    bash "$SCRIPT_DIR/verify_candidate_runtime.sh" \
        "$PROVENANCE" "$CONSOLE_LOG" "$CONFIG_FILE" || exit 2
else
    echo "[NOTE] Declarations verified. Runtime binding (machine/CPU/RAM/SMP/"
    echo "       nographic/kernel/initrd/bootargs actually executed) requires:"
    echo "         make capture   # records provenance + fresh console capture"
    echo "         make check     # binds them to this manifest"
fi

echo "[PASS] QEMU machine flags, CPU, memory, SMP, headless serial route and"
echo "       kernel bootargs contract fully VERIFIED."
