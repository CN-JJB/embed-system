#!/usr/bin/env bash
# Learner/reviewer isolation audit for P3-M08 (port of the P3-M06 audit).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJ_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$PROJ_ROOT"

echo "=================================================================="
echo "=== P3-M08 Learner/Reviewer Isolation Audit                    ==="
echo "=================================================================="

VIOLATIONS=0

LEARNER_FIND=(
    find . -type f
    -not -path "./reviewer/*"
    -not -path "./.git/*"
    -not -path "./build/*"
    -not -name "*.log"
    -not -name "*.provenance"
    -not -name "*.run.json"
)

# --- Rule 1: no learner-facing file may reference the reviewer subtree -------
while IFS= read -r file; do
    if grep -Il -- "reviewer/" "$file" >/dev/null 2>&1; then
        echo "[ISOLATION VIOLATION] learner-facing file references 'reviewer/': $file"
        grep -In -- "reviewer/" "$file" | sed 's/^/      /'
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done < <("${LEARNER_FIND[@]}")

# --- Rule 2: no reviewer-only filename may appear outside reviewer/ ----------
REVIEWER_ONLY_NAMES=(
    "test_*_transfer_mutations.sh"
    "test_*_mutations.sh"
    "test_*_oracle_mutations.sh"
    "test_*_provenance_negatives.sh"
    "run_*_reviewer_check.sh"
    "generate_*_fixtures.sh"
    "audit_learner_isolation.sh"
    "*complete.json"
    "*_seed.json"
    "oracle_*.sh"
    "grade_*.sh"
    "hints.md"
)
for name in "${REVIEWER_ONLY_NAMES[@]}"; do
    while IFS= read -r file; do
        echo "[ISOLATION VIOLATION] reviewer-only filename leaked: $file"
        VIOLATIONS=$((VIOLATIONS + 1))
    done < <(find . -type f -not -path "./reviewer/*" -not -path "./.git/*" -name "$name")
done

# --- Rule 3: hidden transfer seeds must not appear in learner files -----------
# Tutorial faults (fault-a / fault-b READMEs) are public teaching content and
# are excluded from this scan by using transfer-only signatures that never
# appear in tutorial docs.
SEED_SCAN_FIND=(
    find . -type f
    -not -path "./reviewer/*"
    -not -path "./.git/*"
    -not -path "./build/*"
    -not -name "*.log"
    -not -name "*.provenance"
)
HIDDEN_SIGNATURES=(
    'badinit-hidden-transfer'
    'TRANSFER-HIDDEN-UNAVAILABLE'
    'm08-complete-v1'
)
for sig in "${HIDDEN_SIGNATURES[@]}"; do
    while IFS= read -r file; do
        if grep -IFq -- "$sig" "$file" 2>/dev/null; then
            echo "[ISOLATION VIOLATION] hidden transfer seed present in"
            echo "      learner-facing file: $file"
            echo "      signature: $sig"
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
    done < <("${SEED_SCAN_FIND[@]}")
done

# --- Rule 4: learner scripts must never import reviewer code ------------------
while IFS= read -r file; do
    if grep -Eq 'reviewer/(test_m08|audit_learner|reference)' "$file" 2>/dev/null; then
        echo "[ISOLATION VIOLATION] learner script imports reviewer code: $file"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
    if grep -Eq 'appliance_complete\.json' "$file" 2>/dev/null; then
        echo "[ISOLATION VIOLATION] learner script reads hidden reference: $file"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done < <(find ./scripts ./src ./faults ./fixtures -type f 2>/dev/null)

if [ "$VIOLATIONS" -eq 0 ]; then
    echo "=== ISOLATION AUDIT PASS: zero learner->reviewer dependencies, zero seed leaks ==="
    exit 0
fi
echo "=== ISOLATION AUDIT FAIL: $VIOLATIONS violation(s) ===" >&2
exit 1
