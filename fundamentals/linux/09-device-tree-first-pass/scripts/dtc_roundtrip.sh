#!/usr/bin/env bash
# Real `dtc` workflow for Lab 5.2: DTB -> DTS -> DTB with semantic verification.
#
# The learner must prove that decompilation/recompilation produces a
# structurally valid tree.  Byte equality is the wrong test and raw string
# presence is the wrong test; the proof is the semantic comparison performed by
# scripts/dt_roundtrip_check.py, which is run automatically at the end.
#
# Usage:
#   scripts/dtc_roundtrip.sh INPUT.dtb [WORKDIR]
#
# Environment:
#   DTC   path to dtc (default: first `dtc` on PATH)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M05_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M05_ROOT"

INPUT="${1:?usage: dtc_roundtrip.sh INPUT.dtb [WORKDIR]}"
WORKDIR="${2:-build/roundtrip}"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

DTC="${DTC:-}"
if [ -z "$DTC" ]; then
    DTC=$(command -v dtc || true)
fi
if [ -z "$DTC" ] || [ ! -x "$DTC" ]; then
    echo "ERROR: dtc not found." >&2
    echo "       Set DTC=/path/to/dtc, or install the Device Tree Compiler." >&2
    echo "       Canonical curriculum baseline: DTC v1.7.0 (tag v1.7.0," >&2
    echo "       peeled commit 039a99414e778332d8f9c04cbd3072e1dcc62798)." >&2
    exit 2
fi

[ -f "$INPUT" ] || { echo "ERROR: no such DTB: $INPUT" >&2; exit 2; }
mkdir -p "$WORKDIR"

BASE=$(basename "$INPUT" .dtb)
DTS="$WORKDIR/$BASE.dts"
REBUILT="$WORKDIR/$BASE.rebuilt.dtb"

echo "=== [1/4] dtc version ==="
"$DTC" --version

echo "=== [2/4] dtb -> dts ==="
"$DTC" -I dtb -O dts "$INPUT" -o "$DTS"
echo "[OK] $DTS ($(wc -l < "$DTS" | tr -d ' ') lines)"

echo "=== [3/4] dts -> dtb ==="
"$DTC" -I dts -O dtb "$DTS" -o "$REBUILT"
echo "[OK] $REBUILT ($(wc -c < "$REBUILT" | tr -d ' ') bytes)"

echo "=== [4/4] semantic equivalence (the actual proof) ==="
"$PY" scripts/dt_roundtrip_check.py "$INPUT" "$REBUILT"

echo "[OK] round trip verified: the rebuilt tree is semantically identical to the input tree"
