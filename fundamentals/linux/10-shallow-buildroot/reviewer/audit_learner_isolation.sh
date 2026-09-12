#!/usr/bin/env bash
# Automated learner/reviewer isolation audit (P3-M06).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M06_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M06_ROOT"

echo "=================================================================="
echo "=== P3-M06 Learner/Reviewer Isolation Audit                    ==="
echo "=================================================================="

VIOLATIONS=0

LEARNER_FIND=(
    find . -type f
    -not -path "./reviewer/*"
    -not -path "./.git/*"
    -not -path "./challenge/build/*"
    -not -path "./gate/build/*"
    -not -path "./build/*"
    -not -name "*.log"
    -not -name "*.provenance"
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
# The seeded *artifact* itself is excluded: it is the puzzle the learner must
# diagnose, not the answer.  What must not happen is the seed appearing in
# learner documentation, scripts or build logic.
SEED_SCAN_FIND=(
    find . -type f
    -not -path "./reviewer/*"
    -not -path "./.git/*"
    -not -path "./build/*"
    -not -path "./gate/fixtures/*"
    -not -path "./challenge/fixtures/*"
    -not -path "./challenge/build/*"
    -not -path "./gate/build/*"
    -not -name "*.log"
    -not -name "*.provenance"
)
GATE_SIGNATURES=(
    '6.6.30'
    'rootfs-overlay-legacy'
    '# BR2_TARGET_ROOTFS_CPIO_GZIP is not set'
    'qemu-virt-a7-complete'
)
for sig in "${GATE_SIGNATURES[@]}"; do
    while IFS= read -r file; do
        if grep -IFq -- "$sig" "$file" 2>/dev/null; then
            echo "[ISOLATION VIOLATION] scored Gate seed / complete contract present in"
            echo "      learner-facing file: $file"
            echo "      signature: $sig"
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
    done < <("${SEED_SCAN_FIND[@]}")
done

# --- Rule 4: learner build logic must not write the repaired answer ---------
while IFS= read -r file; do
    if grep -Eq 'BR2_ARM_EABIHF=y' "$file" 2>/dev/null && \
       grep -Eq 'BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="6\.18\.50"' "$file" 2>/dev/null && \
       grep -Eq 'BR2_TARGET_ROOTFS_CPIO_GZIP=y' "$file" 2>/dev/null; then
        # The canonical defconfig is public curriculum content and lives under
        # fixtures/; what must not happen is a challenge/gate Makefile emitting
        # the full repaired answer.
        case "$file" in
            ./challenge/*|./gate/*)
                echo "[ISOLATION VIOLATION] assessment build logic writes the repaired answer: $file"
                VIOLATIONS=$((VIOLATIONS + 1)) ;;
        esac
    fi
done < <(find ./challenge ./gate -type f -name "Makefile" 2>/dev/null)

if [ "$VIOLATIONS" -eq 0 ]; then
    echo "=== ISOLATION AUDIT PASS: zero learner->reviewer dependencies, zero seed leaks ==="
    exit 0
fi
echo "=== ISOLATION AUDIT FAIL: $VIOLATIONS violation(s) ===" >&2
exit 1
