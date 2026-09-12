#!/usr/bin/env bash
# Automated learner/reviewer isolation audit (P3-M05).
#
# Rejects learner-facing material that:
#   1. contains a direct "reviewer/" path dependency;
#   2. carries a reviewer-only filename outside reviewer/;
#   3. embeds an answer-bearing mutation recipe for the scored Gate seed;
#   4. embeds the complete reviewer contract profile outside reviewer/.
#
# The reviewer/ subtree itself is exempt.  Rules 3 and 4 are what keep the
# Module Gate genuinely unfamiliar: the Gate's seeded edits must not appear as a
# copy-pasteable command anywhere a learner can read.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M05_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M05_ROOT"

echo "=================================================================="
echo "=== P3-M05 Learner/Reviewer Isolation Audit                    ==="
echo "=================================================================="

VIOLATIONS=0

LEARNER_FIND=(
    find . -type f
    -not -path "./reviewer/*"
    -not -path "./.git/*"
    -not -path "./challenge/build/*"
    -not -path "./gate/build/*"
    -not -path "./build/*"
    -not -name "*.dtb"
    -not -name "*.log"
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
    "oracle_*.sh"
    "test_*_mutations.sh"
    "test_*_oracle_mutations.sh"
    "grade_*_gate.sh"
    "run_*_reviewer_check.sh"
    "audit_learner_isolation.sh"
    "generate_*_fixtures.sh"
    "*_seed.json"
    "*complete.json"
    "M0[0-9]_SOLUTION.md"
    "hints.md"
)

for name in "${REVIEWER_ONLY_NAMES[@]}"; do
    while IFS= read -r file; do
        echo "[ISOLATION VIOLATION] reviewer-only filename leaked: $file"
        VIOLATIONS=$((VIOLATIONS + 1))
    done < <(find . -type f -not -path "./reviewer/*" -not -path "./.git/*" -name "$name")
done

# --- Rule 3: the scored Gate seed must not be a copy-pasteable recipe --------
# Signatures are derived from reviewer/reference/gate_seed.json.
GATE_SIGNATURES=(
    'set-cells "/pl061@9030000" reg'
    'set-string "/pl061@9030000" status'
    'set-cells "/virtio_mmio@a000200" reg'
    '0x00 0x0a000200 0x00 0x400'
    '0, 167772672, 0, 1024'
)
for sig in "${GATE_SIGNATURES[@]}"; do
    while IFS= read -r file; do
        if grep -IFq -- "$sig" "$file" 2>/dev/null; then
            echo "[ISOLATION VIOLATION] scored Gate seed recipe present in learner-facing file: $file"
            echo "      signature: $sig"
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
    done < <("${LEARNER_FIND[@]}")
done

# --- Rule 4: the complete reviewer contract must not be learner-facing ------
# The validator generically supports a "virtio_windows" check, which is fine:
# what must not leak is the reviewer profile's actual contents.
COMPLETE_MARKERS=(
    'qemu-virt-a7-complete'
    '"count": 32'
    '"first_spi": 16'
)
for marker in "${COMPLETE_MARKERS[@]}"; do
    while IFS= read -r file; do
        if grep -IFq -- "$marker" "$file" 2>/dev/null; then
            echo "[ISOLATION VIOLATION] complete reviewer contract leaked: $file"
            echo "      marker: $marker"
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
    done < <("${LEARNER_FIND[@]}")
done

# --- Rule 5: learner build logic must not write the repaired answer ---------
while IFS= read -r file; do
    if grep -Eq 'status[[:space:]]*=[[:space:]]*"okay"' "$file" 2>/dev/null; then
        echo "[ISOLATION VIOLATION] learner-facing build logic writes a repaired answer: $file"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done < <(find ./challenge ./gate -type f -name "Makefile" 2>/dev/null)

if [ "$VIOLATIONS" -eq 0 ]; then
    echo "=== ISOLATION AUDIT PASS: zero learner->reviewer dependencies, zero seed leaks ==="
    exit 0
fi
echo "=== ISOLATION AUDIT FAIL: $VIOLATIONS violation(s) ===" >&2
exit 1
