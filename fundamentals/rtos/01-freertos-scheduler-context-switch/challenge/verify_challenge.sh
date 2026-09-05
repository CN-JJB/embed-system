#!/usr/bin/env bash
# ==============================================================================
# verify_challenge.sh: Learner Verification Runner for P2-M04 Challenge
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-${SCRIPT_DIR}/starter}"

echo "Running P2-M04 Challenge verification against: ${TARGET_DIR}"
bash "${SCRIPT_DIR}/validate.sh" "${TARGET_DIR}"
