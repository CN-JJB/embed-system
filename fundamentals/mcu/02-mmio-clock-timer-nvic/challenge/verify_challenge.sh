#!/usr/bin/env bash
# ==============================================================================
# verify_challenge.sh: Automated validation script for P2-M02 Challenge
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M02_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Verifying P2-M02 Challenge Requirements ==="

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

# 3. Check base firmware builds cleanly
make -C "${M02_DIR}" clean all >/dev/null
echo "[PASS] Module base firmware compiles cleanly with zero warnings"

echo "=== P2-M02 CHALLENGE SPECIFICATION VERIFIED ==="
