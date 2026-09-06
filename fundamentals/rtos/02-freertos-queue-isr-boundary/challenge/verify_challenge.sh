#!/usr/bin/env bash
# ==============================================================================
# verify_challenge.sh: Student Convenience Runner for P2-M05 Challenge
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${SCRIPT_DIR}/validate.sh" "${SCRIPT_DIR}/starter"
