#!/bin/bash
set -euo pipefail

# Reviewer Master Check for P3-M03
# 1. Audits learner/reviewer isolation
# 2. Runs gate grading oracle on reference gate artifact
# 3. Runs adversarial mutation suite

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

echo "================================================================"
echo "=== Running P3-M03 Reviewer Master Verification Suite        ==="
echo "================================================================"

# 1. Learner Isolation Audit
echo "=== Step 1: Auditing Learner-Facing Isolation ==="
# Learner files must not invoke or import from reviewer/
LEAKED=$(grep -rn "reviewer/" "$M03_ROOT/labs" "$M03_ROOT/faults" "$M03_ROOT/challenge" "$M03_ROOT/gate" "$M03_ROOT/scripts" "$M03_ROOT/README.md" "$M03_ROOT/Makefile" 2>/dev/null || true)
if [ -n "$LEAKED" ]; then
    echo "ERROR: Reviewer directory leakage found in learner-facing files:" >&2
    echo "$LEAKED" >&2
    exit 1
fi
echo "[PASS] Isolation audit passed: No reviewer references found in learner-facing files"

# 2. Gate Grading Oracle Verification
echo "=== Step 2: Testing Gate Grading Oracle on Gate Build ==="
make -C "$M03_ROOT" gate-build CROSS_COMPILE="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}" >/dev/null
bash "$M03_ROOT/reviewer/grade_m03_gate.sh" "$M03_ROOT/gate/build/rootfs_gate.cpio.gz"
echo "[PASS] Gate grading oracle successfully evaluated clean gate artifact"

# 3. Mutation Testing
echo "=== Step 3: Executing Adversarial Mutation Suite ==="
bash "$M03_ROOT/reviewer/test_m03_mutations.sh"

echo "================================================================"
echo "=== ALL P3-M03 REVIEWER CHECKS PASSED                        ==="
echo "================================================================"
