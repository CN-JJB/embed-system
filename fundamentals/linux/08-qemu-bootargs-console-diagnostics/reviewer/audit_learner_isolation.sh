#!/bin/bash
set -euo pipefail

# Automated learner/reviewer isolation audit (P3-M04)
# Rejects learner-facing material that:
#   1. contains a direct "reviewer/" path dependency
#   2. carries a reviewer-only filename outside reviewer/
#   3. authors canonical scored bootargs in learner build logic
#      (learner Makefiles must provision/capture/check, never write the
#      canonical BOOTARGS answer; READMEs may state the contract).
# The reviewer/ subtree itself is exempt.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MODULE_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

echo "=================================================================="
echo "=== P3-M04 Learner/Reviewer Isolation Audit                    ==="
echo "=================================================================="

VIOLATIONS=0

# --- Rule 1: no learner-facing file may contain a direct "reviewer/" path ---
while IFS= read -r file; do
    if grep -Il -- "reviewer/" "$file" >/dev/null 2>&1; then
        echo "[ISOLATION VIOLATION] Learner-facing file contains direct 'reviewer/' dependency:"
        echo "    $file"
        grep -In -- "reviewer/" "$file" | sed 's/^/      /'
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done < <(find "$MODULE_ROOT" -type f \
    -not -path "$MODULE_ROOT/reviewer/*" \
    -not -path "*/.git/*" \
    -not -path "$MODULE_ROOT/challenge/build/*" \
    -not -path "$MODULE_ROOT/gate/build/*" \
    -not -path "$MODULE_ROOT/challenge/fixtures/*" \
    -not -path "$MODULE_ROOT/gate/fixtures/*" \
    -not -name "*.log")

# --- Rule 2: no learner-facing file may carry a reviewer-only filename ---
REVIEWER_ONLY_NAMES=(
    "generate_*_fixtures.sh"
    "test_*_mutations.sh"
    "test_*_oracle_mutations.sh"
    "oracle_*.sh"
    "grade_*_gate.sh"
    "run_*_reviewer_check.sh"
    "audit_learner_isolation.sh"
    "M0[1-9]_SOLUTION.md"
    "hints.md"
)

for name in "${REVIEWER_ONLY_NAMES[@]}"; do
    while IFS= read -r file; do
        echo "[ISOLATION VIOLATION] Reviewer-only filename leaked into learner-facing tree:"
        echo "    $file"
        VIOLATIONS=$((VIOLATIONS + 1))
    done < <(find "$MODULE_ROOT" -type f \
        -not -path "$MODULE_ROOT/reviewer/*" \
        -not -path "*/.git/*" \
        -not -path "$MODULE_ROOT/challenge/build/*" \
        -not -path "$MODULE_ROOT/gate/build/*" \
        -name "$name")
done

# --- Rule 3: learner build logic must not write the canonical answer ---
# challenge/gate Makefiles may copy opaque fixtures and capture logs, but
# must never emit the canonical BOOTARGS / machine-answer lines.
while IFS= read -r file; do
    if grep -Eq 'BOOTARGS="earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init"' "$file" 2>/dev/null; then
        echo "[ISOLATION VIOLATION] Learner-facing build logic writes the canonical answer:"
        echo "    $file"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
    if grep -Eq 'MACHINE="-machine virt,highmem=off,gic-version=2"' "$file" 2>/dev/null; then
        echo "[ISOLATION VIOLATION] Learner-facing build logic writes the canonical machine contract:"
        echo "    $file"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done < <(find "$MODULE_ROOT/challenge" "$MODULE_ROOT/gate" -type f -name "Makefile" \
    -not -path "*/.git/*" 2>/dev/null)

if [ "$VIOLATIONS" -eq 0 ]; then
    echo "=== ISOLATION AUDIT PASS: zero learner->reviewer dependencies ==="
    exit 0
else
    echo "=== ISOLATION AUDIT FAIL: $VIOLATIONS violation(s) ===" >&2
    exit 1
fi
