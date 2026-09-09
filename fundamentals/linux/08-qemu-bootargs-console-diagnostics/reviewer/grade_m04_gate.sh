#!/bin/bash
set -euo pipefail

# Reviewer Grading Oracle for P3-M04 Gate
# Verifies canonical machine parameters, bootargs contract, and milestone ordering.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

CONFIG_FILE="${1:-$M04_ROOT/gate/build/gate_boot_config.sh}"
LOG_FILE="${2:-$M04_ROOT/fixtures/reference_boot.log}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "REJECT: Gate configuration file '$CONFIG_FILE' does not exist." >&2
    exit 2
fi

echo "=== Grading P3-M04 Gate Submission ==="

# 1. Audit Boot Contract
bash "$M04_ROOT/scripts/verify_boot_contract.sh" "$CONFIG_FILE"

# 2. Audit Boot Milestones
if [ -f "$LOG_FILE" ]; then
    bash "$M04_ROOT/scripts/audit_boot_milestones.sh" "$LOG_FILE"
else
    echo "REJECT: Boot milestone log '$LOG_FILE' missing." >&2
    exit 2
fi

echo "[PASS] P3-M04 Gate Submission: VERIFIED (100/100)"
