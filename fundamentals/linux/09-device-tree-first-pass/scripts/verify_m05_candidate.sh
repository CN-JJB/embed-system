#!/usr/bin/env bash
# Learner-safe self-check for a P3-M05 candidate DTB.
#
# This checks *packaging and format* invariants only:
#   * the candidate exists and is a parseable device tree blob;
#   * the tree is internally consistent (unique siblings/properties, resolving
#     phandle references, cell arithmetic that matches the declaring parent);
#   * an identity hash is recorded next to the candidate.
#
# It deliberately does NOT evaluate the semantic contract, because doing so
# would hand the learner the scored diagnosis.  Semantic conformance is graded
# by the reviewer oracle; the learner is expected to prove it with their own
# decompilation, hardware-model cross-check and (optionally) a real boot.
#
# Usage:
#   scripts/verify_m05_candidate.sh CANDIDATE.dtb [PROVENANCE] [CONSOLE_LOG]
#
# When a provenance file and console log are supplied the runtime binding check
# is also run; that check is *evidence binding*, not answer grading, so it is
# safe to expose.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M05_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M05_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

CANDIDATE="${1:?usage: verify_m05_candidate.sh CANDIDATE.dtb [PROVENANCE] [LOG]}"
PROVENANCE="${2:-}"
CONSOLE_LOG="${3:-}"

[ -f "$CANDIDATE" ] || { echo "REJECT: candidate DTB not found: $CANDIDATE" >&2; exit 1; }

echo "================================================================"
echo "=== P3-M05 candidate self-check (learner-safe)                ==="
echo "=== candidate: $CANDIDATE"
echo "================================================================"

# Format / structure only.  Exit code 2 (unparseable artifact) is surfaced as
# an ERROR rather than a rejection: a corrupt file is a tool problem, not a
# wrong answer.
"$PY" scripts/dt_structural_check.py "$CANDIDATE"

if command -v sha256sum >/dev/null 2>&1; then
    echo "[INFO] candidate sha256: $(sha256sum "$CANDIDATE" | awk '{print $1}')"
fi

echo "[NOTE] Format/structure verified.  Semantic conformance against the"
echo "       canonical QEMU virt contract is graded by the reviewer oracle."

if [ -n "$PROVENANCE" ] || [ -n "$CONSOLE_LOG" ]; then
    if [ -z "$PROVENANCE" ] || [ -z "$CONSOLE_LOG" ]; then
        echo "REJECT: runtime binding needs BOTH a provenance file and a console log" >&2
        exit 1
    fi
    "$PY" scripts/verify_runtime_binding.py "$CANDIDATE" "$PROVENANCE" "$CONSOLE_LOG"
fi

echo "=== P3-M05 CANDIDATE SELF-CHECK COMPLETE ==="
