#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Verifying P2-M01 Challenge Validator ==="

# 1. Target directory validation (default to reference if not provided)
TARGET_DIR="${1:-${SCRIPT_DIR}/reference}"
bash "${SCRIPT_DIR}/validate.sh" "${TARGET_DIR}"

# 2. Regression check: confirm incomplete starter fails validation
echo "Checking that incomplete starter fails validation as expected..."
if bash "${SCRIPT_DIR}/validate.sh" "${SCRIPT_DIR}/starter" >/dev/null 2>&1; then
    echo "ERROR: Starter unexpectedly passed validation!" >&2
    exit 1
fi
echo "[PASS] Negative test confirmed: incomplete starter correctly fails validation"

echo "=== P2-M01 CHALLENGE VERIFIED SUCCESSFULLY ==="

