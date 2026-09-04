#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M01_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Verifying Challenge Requirements ==="
# Run standard module verification
bash "${M01_DIR}/scripts/verify_m01.sh"
echo "=== CHALLENGE VERIFIED SUCCESSFULLY ==="
