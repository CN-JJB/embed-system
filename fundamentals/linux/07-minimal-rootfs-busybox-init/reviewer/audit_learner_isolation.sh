#!/bin/bash
set -euo pipefail

# Automated learner/reviewer isolation audit (P3-M03)
# Rejects learner-facing material that:
#   1. contains a direct "reviewer/" path dependency (make/shell/markdown/etc.)
#   2. carries a reviewer-only filename outside reviewer/
#   3. leaks hidden assessment mapping tokens (defect seeds, reference paths)
#   4. ships a human-readable scored mutation recipe in the fixture inputs
#      (the assignment inputs must stay opaque; only the provisioned
#      candidate tree itself is diagnosed)
# The reviewer/ subtree itself is exempt. Learner workflows must never
# depend on reviewer generators, oracles, mutation suites, or solutions.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MODULE_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

echo "=================================================================="
echo "=== P3-M03 Learner/Reviewer Isolation Audit                    ==="
echo "=================================================================="

VIOLATIONS=0

# --- Rule 1: no learner-facing file may contain a direct "reviewer/" path ---
# Note: .gitignore hygiene entries (ignoring generated reviewer reference
# trees) are not code dependencies and are exempt.
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
    -not -path "$MODULE_ROOT/fixtures/build/*" \
    -not -path "$MODULE_ROOT/challenge/build/*" \
    -not -path "$MODULE_ROOT/gate/build/*" \
    -not -path "$MODULE_ROOT/challenge/fixtures/*" \
    -not -path "$MODULE_ROOT/gate/fixtures/*" \
    -not -name ".gitignore" \
    -not -name "*.o" -not -name "*.elf")

# --- Rule 2: no learner-facing file may carry a reviewer-only filename ---
REVIEWER_ONLY_NAMES=(
    "generate_*_fixtures.sh"
    "test_*_mutations.sh"
    "test_*_oracle_mutations.sh"
    "test_*_layer_safety.sh"
    "check_repo_hygiene.sh"
    "scan_recipe_text.sh"
    "make_candidate_layer.py"
    "oracle_*.sh"
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
        -not -path "$MODULE_ROOT/fixtures/build/*" \
        -not -path "$MODULE_ROOT/challenge/build/*" \
        -not -path "$MODULE_ROOT/gate/build/*" \
        -name "$name")
done

# --- Rule 3: learner-facing build logic must not encode scored answers ---
# Learner Makefiles may provision opaque fixtures and run generic validators,
# but must never write inittab/rcS scored content or reference fixes.
while IFS= read -r file; do
    if grep -E -q "askfirst|::sysinit:" "$file" 2>/dev/null; then
        # READMEs state the production contract (allowed); Makefiles and
        # shell scripts must not author the scored lines.
        case "$file" in
            *.md) ;;
            *)
                echo "[ISOLATION VIOLATION] Learner-facing build/script authors scored init content:"
                echo "    $file"
                VIOLATIONS=$((VIOLATIONS + 1))
                ;;
        esac
    fi
done < <(find "$MODULE_ROOT/challenge" "$MODULE_ROOT/gate" -type f \
    -not -path "$MODULE_ROOT/challenge/fixtures/*" \
    -not -path "$MODULE_ROOT/gate/fixtures/*" \
    -not -path "$MODULE_ROOT/challenge/build/*" \
    -not -path "$MODULE_ROOT/gate/build/*" \
    -not -path "*/.git/*" 2>/dev/null)

# --- Rule 4: no human-readable scored mutation recipe in fixture inputs ---
# The retired plaintext recipe names (operation manifest, overlay tree) and
# any recipe/decoy cleartext under the scored fixture inputs are rejected.
# The opaque candidate.layer assignment inputs are binary and pass the text
# scan below (grep -I skips non-text).
for recipe in "$MODULE_ROOT/challenge/fixtures/defects.manifest" \
              "$MODULE_ROOT/gate/fixtures/defects.manifest"; do
    if [ -e "$recipe" ]; then
        echo "[ISOLATION VIOLATION] Retired human-readable mutation recipe present:"
        echo "    $recipe"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done
for overlay in "$MODULE_ROOT/challenge/fixtures/defective_overlay" \
               "$MODULE_ROOT/gate/fixtures/defective_overlay"; do
    if [ -e "$overlay" ]; then
        echo "[ISOLATION VIOLATION] Retired plaintext assessment overlay present:"
        echo "    $overlay"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done
if ! bash "$MODULE_ROOT/reviewer/scripts/scan_recipe_text.sh" \
        "$MODULE_ROOT/challenge/fixtures" \
        "$MODULE_ROOT/gate/fixtures" >/dev/null 2>&1; then
    echo "[ISOLATION VIOLATION] Learner-visible fixture inputs carry recipe cleartext:"
    bash "$MODULE_ROOT/reviewer/scripts/scan_recipe_text.sh" \
        "$MODULE_ROOT/challenge/fixtures" \
        "$MODULE_ROOT/gate/fixtures" 2>&1 | sed 's/^/    /' || true
    VIOLATIONS=$((VIOLATIONS + 1))
fi

if [ "$VIOLATIONS" -eq 0 ]; then
    echo "=== ISOLATION AUDIT PASS: zero learner->reviewer dependencies ==="
    exit 0
else
    echo "=== ISOLATION AUDIT FAIL: $VIOLATIONS violation(s) ===" >&2
    exit 1
fi
