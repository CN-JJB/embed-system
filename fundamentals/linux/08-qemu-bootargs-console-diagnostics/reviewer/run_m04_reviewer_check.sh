#!/bin/bash
set -euo pipefail

# P3-M04 Reviewer-Only Full Authoring Regression (REVIEWER-ONLY)
# Orchestrates, in order:
#   1. learner/reviewer isolation audit
#   2. assessment fixture materialization (opaque manifests + references)
#   3. learner-safe check re-run (must pass without reviewer tooling)
#   4. component-validator negative control mutation suite
#   5. assessment oracle reference + mutation regression, including a fresh
#      candidate-bound QEMU capture of the canonical reference manifest and
#      the executed-argv override controls (machine/CPU/MEM/SMP decoys)
# Learner workflows must never invoke this script.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M04_ROOT"

echo "##################################################################"
echo "# P3-M04 REVIEWER-CHECK — AUTHORING REGRESSION (REVIEWER-ONLY)  #"
echo "##################################################################"

echo ""
echo "===== [1/6] Learner/Reviewer Isolation Audit ====="
bash reviewer/audit_learner_isolation.sh

echo ""
echo "===== [2/6] Materialize Assessment Manifests (opaque) ====="
bash reviewer/scripts/generate_m04_challenge_fixtures.sh challenge/fixtures
bash reviewer/scripts/generate_m04_gate_fixtures.sh gate/fixtures
echo "[PASS] M04 assessment manifests + reviewer references materialized."

echo ""
echo "===== [3/6] Learner-Safe Module Check (no reviewer tooling) ====="
make check

echo ""
echo "===== [4/6] Component-Validator Negative Control Mutations ====="
bash reviewer/test_m04_mutations.sh

echo ""
echo "===== [5/6] Manifest Parser / Normalizer Self-Test ====="
python3 scripts/parse_candidate_manifest.py \
    --manifest reviewer/reference/gate_manifest.conf >/dev/null
echo "[PASS] Canonical reference manifest parses into a normalized QEMU argv."
python3 scripts/parse_candidate_manifest.py \
    --manifest "$M04_ROOT/gate/fixtures/starter_manifest.conf" >/dev/null 2>&1 \
    && { echo "REJECT: opaque starter manifest unexpectedly satisfied the canonical contract." >&2; exit 1; } \
    || echo "[PASS] Opaque starter manifest rejected by the parser (expected)."

echo ""
echo "===== [6/6] Assessment Oracle Reference + Mutation Regression ====="
bash reviewer/test_m04_oracle_mutations.sh

echo ""
echo "=== P3-M04 REVIEWER-CHECK COMPLETE: ALL STAGES PASSED ==="
