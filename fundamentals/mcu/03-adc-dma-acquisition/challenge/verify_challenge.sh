#!/usr/bin/env bash
# ==============================================================================
# verify_challenge.sh: Automated validation script for P2-M03 Challenge
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Verifying P2-M03 Challenge Validator ==="

# 1. Target directory validation (defaults to reviewer reference if not provided)
TARGET_DIR="${1:-${SCRIPT_DIR}/../reviewer/challenge-reference}"
bash "${SCRIPT_DIR}/validate.sh" "${TARGET_DIR}"

# 2. Regression check: run mutation suite
echo "Running mutation regression suite..."
bash "${SCRIPT_DIR}/../reviewer/test_m03_validator_mutations.sh"

echo "=== P2-M03 CHALLENGE SPECIFICATION VERIFIED ==="
