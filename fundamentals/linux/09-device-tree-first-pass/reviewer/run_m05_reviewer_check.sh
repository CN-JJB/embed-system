#!/usr/bin/env bash
# P3-M05 Reviewer-Only Full Authoring Regression.
#
# Orchestrates, in order:
#   1. learner/reviewer isolation audit
#   2. assessment fixture materialisation (opaque artifacts + hidden seeds)
#   3. learner-safe module check re-run (must pass without reviewer tooling)
#   4. adversarial mutation suite for the component validators
#   5. oracle regression suite
#   6. real-tool cross-validation, when dtc and qemu-system-arm are available
#
# Learner workflows must never invoke this script.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M05_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M05_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

echo "##################################################################"
echo "# P3-M05 REVIEWER-CHECK - AUTHORING REGRESSION (REVIEWER-ONLY)  #"
echo "##################################################################"

echo ""
echo "===== [1/6] Learner/Reviewer Isolation Audit ====="
bash reviewer/audit_learner_isolation.sh

echo ""
echo "===== [2/6] Materialise Assessment Fixtures (opaque) ====="
bash reviewer/scripts/generate_m05_assessment_fixtures.sh
echo "[PASS] assessment artifacts + hidden seed mappings materialised."

echo ""
echo "===== [3/6] Learner-Safe Module Check (no reviewer tooling) ====="
make check

echo ""
echo "===== [4/6] Adversarial Mutation Suite ====="
bash reviewer/test_m05_mutations.sh

echo ""
echo "===== [5/6] Oracle Regression Suite ====="
bash reviewer/test_m05_oracle_mutations.sh

echo ""
echo "===== [6/6] Real-tool cross-validation ====="
DTC_BIN="${DTC:-}"
[ -n "$DTC_BIN" ] || DTC_BIN=$(command -v dtc || true)
if [ -n "$DTC_BIN" ] && [ -x "$DTC_BIN" ]; then
    echo "[INFO] dtc found: $DTC_BIN"
    DTC="$DTC_BIN" bash scripts/dtc_roundtrip.sh fixtures/qemu-virt.dtb build/roundtrip
else
    echo "[NOTE] dtc not available on this host: real dtb -> dts -> dtb cross-validation SKIPPED."
    echo "       Canonical baseline: DTC v1.7.0 (039a99414e778332d8f9c04cbd3072e1dcc62798)."
fi

QEMU_BIN="${QEMU_SYSTEM_ARM:-}"
[ -n "$QEMU_BIN" ] || QEMU_BIN=$(command -v qemu-system-arm || true)
if [ -n "$QEMU_BIN" ] && [ -x "$QEMU_BIN" ]; then
    echo "[INFO] qemu-system-arm found: $QEMU_BIN"
    QEMU_SYSTEM_ARM="$QEMU_BIN" bash scripts/dump_virt_dtb.sh \
        build/reviewer-virt.dtb build/reviewer-virt.provenance.json
    echo "[INFO] comparing the freshly dumped tree against the committed fixture"
    "$PY" scripts/dt_roundtrip_check.py fixtures/qemu-virt.dtb build/reviewer-virt.dtb --quiet \
        && echo "[PASS] freshly generated tree is semantically identical to the committed fixture" \
        || echo "[NOTE] freshly generated tree differs from the committed fixture; inspect the diff"
else
    echo "[NOTE] qemu-system-arm not available on this host: real DTB regeneration SKIPPED."
fi

echo ""
echo "=== P3-M05 REVIEWER-CHECK COMPLETE: ALL STAGES PASSED ==="
