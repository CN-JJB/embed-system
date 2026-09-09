#!/bin/bash
set -euo pipefail

# Automated learner/reviewer isolation audit (P3-M02)
# Rejects learner-facing material that:
#   1. contains a direct "reviewer/" path dependency (make/shell/markdown/etc.)
#   2. references known reviewer-only filenames
# The reviewer/ subtree itself is exempt. Learner workflows must never
# depend on reviewer generators, oracles, mutation suites, or solutions.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MODULE_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

echo "=================================================================="
echo "=== P3-M02 Learner/Reviewer Isolation Audit                    ==="
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
    -not -name "*.o" -not -name "*.elf")

# --- Rule 2: no learner-facing file may carry a reviewer-only filename ---
REVIEWER_ONLY_NAMES=(
    "generate_*_fixtures.sh"
    "test_*_mutations.sh"
    "oracle_*.sh"
    "run_*_reviewer_check.sh"
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
        -name "$name")
done

if [ "$VIOLATIONS" -eq 0 ]; then
    echo "=== ISOLATION AUDIT PASS: zero learner->reviewer dependencies ==="
    exit 0
else
    echo "=== ISOLATION AUDIT FAIL: $VIOLATIONS violation(s) ===" >&2
    exit 1
fi
