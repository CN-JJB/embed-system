#!/usr/bin/env bash
# ==============================================================================
# verify_challenge.sh: Convenience Runner for P2-M04 Challenge
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${SCRIPT_DIR}/validate.sh" "${SCRIPT_DIR}/app_tasks.c"
