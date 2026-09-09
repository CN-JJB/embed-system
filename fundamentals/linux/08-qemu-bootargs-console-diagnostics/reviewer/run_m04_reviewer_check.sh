#!/bin/bash
set -euo pipefail

# P3-M04 Reviewer-Only Full Authoring Regression (REVIEWER-ONLY)
# Orchestrates, in order:
#   1. learner/reviewer isolation audit
#   2. assessment fixture materialization (opaque, committed separately)
#   3. learner-safe check re-run (must pass without reviewer tooling)
#   4. component-validator negative control mutation suite
#   5. assessment oracle reference + mutation regression (includes fresh
#      QEMU runtime capture for the canonical reference)
# Learner workflows must never invoke this script.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M04_ROOT"

echo "##################################################################"
echo "# P3-M04 REVIEWER-CHECK — AUTHORING REGRESSION (REVIEWER-ONLY)  #"
echo "##################################################################"

echo ""
echo "===== [1/5] Learner/Reviewer Isolation Audit ====="
bash reviewer/audit_learner_isolation.sh

echo ""
echo "===== [2/5] Materialize Assessment Fixtures (opaque) ====="
bash reviewer/scripts/generate_m04_challenge_fixtures.sh challenge/fixtures
bash reviewer/scripts/generate_m04_gate_fixtures.sh gate/fixtures
echo "[PASS] M04 assessment fixtures materialized under challenge/ and gate/"

echo ""
echo "===== [3/5] Learner-Safe Module Check (no reviewer tooling) ====="
make check

echo ""
echo "===== [4/5] Component-Validator Negative Control Mutations ====="
bash reviewer/test_m04_mutations.sh

echo ""
echo "===== [5/5] Assessment Oracle Reference + Mutation Regression ====="
bash reviewer/test_m04_oracle_mutations.sh

echo ""
echo "=== P3-M04 REVIEWER-CHECK COMPLETE: ALL STAGES PASSED ==="
