#!/usr/bin/env bash
# Learner-safe self-check for a P3-M06 candidate.
#
# Two artifacts may be submitted, and each is checked for *format and internal
# consistency* only:
#
#   1. a data-only Buildroot configuration fragment (candidate.conf)
#   2. optionally, the output tree produced from it, together with a runtime
#      capture bound to the final image
#
# The semantic contract (which symbols must hold which values) is graded by the
# reviewer oracle; this script does not evaluate it, so it cannot hand the
# learner the scored diagnosis.
#
# Usage:
#   scripts/verify_m06_candidate.sh CANDIDATE.conf [OUTPUT_DIR OVERLAY LOG PROVENANCE]
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M06_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M06_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

CANDIDATE="${1:?usage: verify_m06_candidate.sh CANDIDATE.conf [OUTPUT_DIR OVERLAY LOG PROVENANCE]}"
OUTPUT_DIR="${2:-}"
OVERLAY_DIR="${3:-}"
LOG="${4:-}"
PROVENANCE="${5:-}"

[ -f "$CANDIDATE" ] || { echo "REJECT: candidate fragment not found: $CANDIDATE" >&2; exit 1; }

echo "================================================================"
echo "=== P3-M06 candidate self-check (learner-safe)                ==="
echo "=== fragment: $CANDIDATE"
echo "================================================================"

# --- 1. fragment parses and is structurally a Buildroot configuration -------
"$PY" - "$CANDIDATE" <<'PYEOF'
import sys, os
sys.path.insert(0, "scripts")
from verify_br_config import ConfigError, parse_fragment
try:
    cfg = parse_fragment(sys.argv[1])
except ConfigError as exc:
    print(f"REJECT: {exc}", file=sys.stderr)
    sys.exit(1)
print(f"[PASS] fragment parses: {len(cfg.values)} symbol(s) set, "
      f"{len(cfg.explicitly_unset)} explicitly unset")
PYEOF

echo "[NOTE] Format verified.  Semantic conformance against the canonical"
echo "       Buildroot contract is graded by the reviewer oracle."

# --- 2. optional output-tree audit -----------------------------------------
if [ -n "$OUTPUT_DIR" ] && [ -n "$OVERLAY_DIR" ]; then
    "$PY" scripts/audit_output_tree.py --output "$OUTPUT_DIR" --overlay "$OVERLAY_DIR"
fi

# --- 3. optional runtime binding -------------------------------------------
if [ -n "$LOG" ] || [ -n "$PROVENANCE" ]; then
    if [ -z "$LOG" ] || [ -z "$PROVENANCE" ] || [ -z "$OUTPUT_DIR" ]; then
        echo "REJECT: runtime binding needs OUTPUT_DIR, LOG and PROVENANCE together" >&2
        exit 1
    fi
    IMAGE="$OUTPUT_DIR/images/rootfs.cpio.gz"
    [ -f "$IMAGE" ] || IMAGE="$OUTPUT_DIR/images/rootfs.cpio"
    "$PY" scripts/verify_appliance_runtime.py "$IMAGE" "$PROVENANCE" "$LOG" \
        ${OVERLAY_DIR:+--overlay "$OVERLAY_DIR"}
fi

echo "=== P3-M06 CANDIDATE SELF-CHECK COMPLETE ==="
