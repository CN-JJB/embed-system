#!/usr/bin/env bash
# ==============================================================================
# verify_challenge.sh: Automated validation script for P2-M02 Challenge
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Verifying P2-M02 Challenge Validator ==="

# 1. Verify 10 kHz / 100 us Timer Arithmetic for 100 Hz 100-step PWM
TIMCLK=72000000
PSC=71
ARR=99
FREQ=$(( TIMCLK / ((PSC + 1) * (ARR + 1)) ))

if [ "${FREQ}" -ne 10000 ]; then
    echo "ERROR: Timer frequency math failure! Expected 10000 Hz (100 us), got ${FREQ}" >&2
    exit 1
fi
echo "[PASS] Timer frequency math verified: ${TIMCLK} / ((71 + 1) * (99 + 1)) = ${FREQ} Hz (100 us tick)"

# 2. Verify PWM period and resolution
STEPS=100
PWM_FREQ=$(( FREQ / STEPS ))
if [ "${PWM_FREQ}" -ne 100 ]; then
    echo "ERROR: PWM frequency failure! Expected 100 Hz, got ${PWM_FREQ}" >&2
    exit 1
fi
echo "[PASS] PWM base frequency verified: ${FREQ} Hz / 100 steps = ${PWM_FREQ} Hz"

# 3. Validate target challenge directory (defaults to reference)
TARGET_DIR="${1:-${SCRIPT_DIR}/reference}"
bash "${SCRIPT_DIR}/validate.sh" "${TARGET_DIR}"

# 4. Negative test: confirm incomplete starter fails validation
echo "Checking that incomplete starter fails validation as expected..."
if bash "${SCRIPT_DIR}/validate.sh" "${SCRIPT_DIR}/starter" >/dev/null 2>&1; then
    echo "ERROR: Starter unexpectedly passed validation!" >&2
    exit 1
fi
echo "[PASS] Negative test confirmed: incomplete starter correctly fails validation"

echo "=== P2-M02 CHALLENGE SPECIFICATION VERIFIED ==="
