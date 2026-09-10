#!/bin/bash
set -euo pipefail

# P3-M03 Reviewer-Only Full Authoring Regression (REVIEWER-ONLY)
# Orchestrates, in order:
#   1. learner/reviewer isolation audit
#   2. repository-hygiene regression (no vendored BusyBox staging in Git)
#   3. assessment fixture materialization (on demand from verified staging)
#   4. learner-safe check re-run (must pass without reviewer tooling)
#   5. component-validator negative control mutation suite
#   6. assessment oracle reference + mutation regression
#   7. assignment-layer safety + learner/reviewer equivalence regression
# Learner workflows must never invoke this script.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M03_ROOT"

CROSS_COMPILE="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}"

echo "##################################################################"
echo "# P3-M03 REVIEWER-CHECK — AUTHORING REGRESSION (REVIEWER-ONLY)  #"
echo "##################################################################"

echo ""
echo "===== [1/6] Learner/Reviewer Isolation Audit ====="
bash reviewer/audit_learner_isolation.sh

echo ""
echo "===== [2/6] Repository-Hygiene Regression (no vendored staging) ====="
bash reviewer/scripts/check_repo_hygiene.sh

echo ""
echo "===== [3/6] Materialize Assessment Fixtures (on demand) ====="
bash reviewer/scripts/generate_m03_challenge_fixtures.sh challenge/fixtures "$CROSS_COMPILE"
bash reviewer/scripts/generate_m03_gate_fixtures.sh gate/fixtures "$CROSS_COMPILE"
echo "[PASS] M03 assessment fixtures materialized under challenge/ and gate/ (gitignored)"

echo ""
echo "===== [4/6] Learner-Safe Module Check (no reviewer tooling) ====="
make check CROSS_COMPILE="$CROSS_COMPILE"

echo ""
echo "===== [5/6] Component-Validator Negative Control Mutations ====="
CROSS_COMPILE="$CROSS_COMPILE" bash reviewer/test_m03_mutations.sh

echo ""
echo "===== [6/7] Assessment Oracle Reference + Mutation Regression ====="
bash reviewer/test_m03_oracle_mutations.sh

echo ""
echo "===== [7/7] Assignment-Layer Safety + Equivalence Regression ====="
bash reviewer/test_m03_layer_safety.sh

echo ""
echo "=== P3-M03 REVIEWER-CHECK COMPLETE: ALL STAGES PASSED ==="
