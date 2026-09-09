#!/bin/bash
set -euo pipefail

# Reviewer Master Check for P3-M04
# 1. Audits learner/reviewer isolation
# 2. Runs gate grading oracle on reference gate artifact
# 3. Runs adversarial mutation suite

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

echo "================================================================"
echo "=== Running P3-M04 Reviewer Master Verification Suite        ==="
echo "================================================================"

# 1. Learner Isolation Audit
echo "=== Step 1: Auditing Learner-Facing Isolation ==="
LEAKED=$(grep -rn "reviewer/" "$M04_ROOT/labs" "$M04_ROOT/faults" "$M04_ROOT/challenge" "$M04_ROOT/gate" "$M04_ROOT/scripts" "$M04_ROOT/README.md" "$M04_ROOT/Makefile" 2>/dev/null || true)
if [ -n "$LEAKED" ]; then
    echo "ERROR: Reviewer directory leakage found in learner-facing files:" >&2
    echo "$LEAKED" >&2
    exit 1
fi
echo "[PASS] Isolation audit passed: No reviewer references found in learner-facing files"

# 2. Gate Grading Oracle Verification
echo "=== Step 2: Testing Gate Grading Oracle on Gate Build ==="
make -C "$M04_ROOT/gate" gate-build >/dev/null
bash "$M04_ROOT/reviewer/grade_m04_gate.sh" "$M04_ROOT/gate/build/gate_boot_config.sh" "$M04_ROOT/fixtures/reference_boot.log"
echo "[PASS] Gate grading oracle successfully evaluated clean gate artifact"

# 3. Mutation Testing
echo "=== Step 3: Executing Adversarial Mutation Suite ==="
bash "$M04_ROOT/reviewer/test_m04_mutations.sh"

echo "================================================================"
echo "=== ALL P3-M04 REVIEWER CHECKS PASSED                        ==="
echo "================================================================"
