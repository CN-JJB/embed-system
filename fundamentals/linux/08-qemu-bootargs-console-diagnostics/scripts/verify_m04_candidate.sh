#!/bin/bash
set -euo pipefail

# Wrapper: verify a P3-M04 candidate manifest, and bind its captured runtime
# evidence (provenance + console log) when those artifacts exist.
#
# Usage: verify_m04_candidate.sh <manifest> [provenance] [console-log]
#   provenance defaults to <manifest-dir>/candidate_boot.argv
#   console-log defaults to <manifest-dir>/candidate_boot.log
#
# Learner-safe: it never consults reviewer assets or hidden expectations; it
# only applies the published canonical contract to the learner's own files.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

MANIFEST="${1:-}"
if [ -z "$MANIFEST" ] || [ ! -f "$MANIFEST" ]; then
    echo "ERROR: Candidate manifest required: '${MANIFEST:-<empty>}'" >&2
    exit 1
fi

BUILD_DIR=$(cd "$(dirname "$MANIFEST")" && pwd)
PROVENANCE="${2:-$BUILD_DIR/candidate_boot.argv}"
CONSOLE_LOG="${3:-$BUILD_DIR/candidate_boot.log}"

if [ -f "$PROVENANCE" ] && [ -f "$CONSOLE_LOG" ]; then
    bash "$SCRIPT_DIR/verify_boot_contract.sh" "$MANIFEST" "$PROVENANCE" "$CONSOLE_LOG"
    echo "[PASS] Candidate manifest AND its executed-argv runtime evidence verified."
else
    bash "$SCRIPT_DIR/verify_boot_contract.sh" "$MANIFEST"
    echo "[NOTICE] No captured runtime evidence yet (need $PROVENANCE and $CONSOLE_LOG)."
    echo "         Run: make capture   then re-run this check."
fi
