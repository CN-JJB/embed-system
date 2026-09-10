#!/bin/bash
set -euo pipefail

# Plain-text mutation-recipe scanner (REVIEWER-ONLY helper).
#
# Fails when a learner-visible scored fixture directory contains
# human-readable assessment-recipe text: operation lists that describe the
# baseline diff (e.g. overlay/symlink/remove/chmod lines), retired
# stale-link markers, or scored init-configuration content in cleartext.
# The opaque candidate.layer assignment inputs are binary and are skipped
# by the text scan (grep -I); only decodable text is judged.
#
# Usage: scan_recipe_text.sh <fixture-dir>...
# Only provisioning INPUTS are judged. Materialized candidate trees
# (defective_rootfs/, build/) are the diagnosis subject itself and are
# excluded, as are version-control internals.
# Exit 0: clean. Exit 1: recipe text found (details on stderr).

HITS=0

for dir in "$@"; do
    [ -d "$dir" ] || { echo "REJECT: fixture directory missing: $dir" >&2; exit 1; }
    while IFS= read -r file; do
        # Operation-list language of the retired human-readable recipe.
        if grep -I -E -q '^[[:space:]]*(overlay|symlink|remove|chmod)[[:space:]]+[^[:space:]]' "$file" 2>/dev/null; then
            echo "REJECT: human-readable mutation recipe in: $file" >&2
            grep -I -E -n '^[[:space:]]*(overlay|symlink|remove|chmod)[[:space:]]+[^[:space:]]' "$file" 2>/dev/null | sed 's/^/    /' >&2 || true
            HITS=$((HITS + 1))
        fi
        # Retired stale-link markers (kept as known answer-bearing tokens).
        if grep -I -E -q 'stale_target|nonexistent_target' "$file" 2>/dev/null; then
            echo "REJECT: answer-bearing link marker in: $file" >&2
            HITS=$((HITS + 1))
        fi
        # Scored init-configuration content must never sit in cleartext
        # under the fixture inputs (it lives inside the opaque layer).
        if grep -I -E -q '::sysinit:|askfirst' "$file" 2>/dev/null; then
            echo "REJECT: scored init-configuration cleartext in: $file" >&2
            HITS=$((HITS + 1))
        fi
    done < <(find "$dir" -type f -not -path "*/defective_rootfs/*" -not -path "*/build/*" -not -path "*/.git/*" 2>/dev/null)
done

if [ "$HITS" -eq 0 ]; then
    echo "[PASS] No human-readable mutation recipe in: $*"
    exit 0
fi
echo "REJECT: $HITS recipe-text hit(s) under: $*" >&2
exit 1
