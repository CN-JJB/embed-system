#!/usr/bin/env bash
# Automated learner/reviewer isolation audit (P3-M07).
#
# Learner-facing material must never depend on, import, or disclose reviewer-only
# assessment assets: hidden seeds, reference answer mappings, scoring anchors,
# mutation suites and the semantic oracle.  This audit fails closed.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M07_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M07_ROOT"

echo "=================================================================="
echo "=== P3-M07 Learner/Reviewer Isolation Audit                    ==="
echo "=================================================================="

VIOLATIONS=0

LEARNER_FIND=(
    find . -type f
    -not -path "./reviewer/*"
    -not -path "./.git/*"
    -not -path "./build/*"
    -not -path "./challenge/build/*"
    -not -path "./gate/build/*"
    -not -name "*.log"
    -not -name "*.provenance"
    -not -name "*.argv"
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

# --- Rule 3: hidden seed values must not appear in learner-facing material ---
# The seeded *artifact* under challenge/fixtures and gate/fixtures is excluded:
# it is the puzzle the learner must diagnose, not the answer.  What must not
# happen is the hidden mapping, the oracle's reference words, or the scoring
# anchors appearing in learner documentation, scripts or build logic.
SEED_SCAN_FIND=(
    find . -type f
    -not -path "./reviewer/*"
    -not -path "./.git/*"
    -not -path "./build/*"
    -not -path "./challenge/fixtures/*"
    -not -path "./gate/fixtures/*"
    -not -path "./challenge/build/*"
    -not -path "./gate/build/*"
    -not -name "*.log"
    -not -name "*.provenance"
)

# Signatures are derived from the reviewer-only seed mappings at run time so
# this audit cannot go stale when a seed is rotated.  If the derivation fails we
# fail closed rather than silently auditing nothing.
if [ ! -f reviewer/reference/gate_seed.json ] || [ ! -f reviewer/reference/challenge_seed.json ]; then
    echo "[ISOLATION VIOLATION] reviewer seed mapping missing; cannot audit for leaks" >&2
    exit 1
fi

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

SEED_SIGNATURES_FILE="$(mktemp)"
trap 'rm -f "$SEED_SIGNATURES_FILE"' EXIT

"$PY" - reviewer/reference/gate_seed.json reviewer/reference/challenge_seed.json \
    > "$SEED_SIGNATURES_FILE" <<'PYEOF'
import json
import re
import sys

# Only long, high-entropy, answer-bearing tokens are used as leak signatures.
# Short generic strings (e.g. "0x0") would produce false positives against
# ordinary teaching prose, so they are filtered out.
ALLOWED = re.compile(r"^[0-9A-Fa-f]{8,}$|^0x[0-9A-Fa-f]{6,}$|^[A-Za-z0-9_.\-]{12,}$")
seen = set()
for path in sys.argv[1:]:
    try:
        obj = json.load(open(path, encoding="utf-8"))
    except Exception:
        continue
    stack = [obj]
    while stack:
        node = stack.pop()
        if isinstance(node, dict):
            stack.extend(node.values())
        elif isinstance(node, list):
            stack.extend(node)
        elif isinstance(node, str):
            token = node.strip()
            if token and ALLOWED.match(token):
                seen.add(token)
for token in sorted(seen):
    print(token)
PYEOF

if [ ! -s "$SEED_SIGNATURES_FILE" ]; then
    echo "[ISOLATION VIOLATION] no seed signatures derived; audit cannot be trusted" >&2
    exit 1
fi

SIG_COUNT=$(wc -l < "$SEED_SIGNATURES_FILE")
while IFS= read -r sig; do
    [ -n "$sig" ] || continue
    while IFS= read -r file; do
        if grep -IFq -- "$sig" "$file" 2>/dev/null; then
            echo "[ISOLATION VIOLATION] hidden seed value present in learner-facing file:"
            echo "      file: $file"
            echo "      signature: $sig"
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
    done < <("${SEED_SCAN_FIND[@]}")
done < "$SEED_SIGNATURES_FILE"
echo "[INFO] audited $SIG_COUNT derived seed signature(s) against learner-facing material"

# --- Rule 4: learner-safe scripts must not read reviewer-only assets ---------
# Scanned on *code* lines only: a comment stating that an asset is never read is
# not a dependency.  Deliberately conservative -- the default audit already
# rejects any mention of the assessment subtree (Rule 1); this rule catches the
# narrower case where a script names a private artifact without naming the
# subtree.
while IFS= read -r file; do
    if sed -e 's/#.*$//' "$file" 2>/dev/null \
        | grep -Eq 'oracle_m07|_seed\.json|complete\.json|reference/'; then
        echo "[ISOLATION VIOLATION] learner-safe script reads reviewer-only assets: $file"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done < <(find ./scripts ./challenge ./gate -type f \( -name "*.sh" -o -name "*.py" -o -name "Makefile" \) 2>/dev/null)

# --- Rule 5: learner-safe check must not execute graded oracle scoring -------
if sed -e 's/#.*$//' scripts/verify_m07.sh 2>/dev/null \
    | grep -Eq 'oracle_m07|grade_.*gate|score'; then
    echo "[ISOLATION VIOLATION] learner-safe verify_m07.sh invokes grading logic"
    VIOLATIONS=$((VIOLATIONS + 1))
fi

# --- Rule 6: scored starters must not narrate their own defects --------------
# The Rule 3 scan only catches *verbatim* seed values.  A starter can pass that
# and still hand the learner the answer in prose: naming the corrupted field,
# the aspect class, the correct value or the tutorial family.  Scoring validity
# depends on the learner doing that diagnosis.
#
# Two independent JSON-aware checks, because a grep over raw text is easy to
# slip past (a field can be renamed, or the wording rephrased):
#   6a  no answer-bearing KEY may appear anywhere in a scored starter;
#   6b  no string VALUE may carry answer-narrating vocabulary.
# A structural allowlist was rejected as more brittle than it is worth: adding a
# legitimate display field would break it.  The key denylist targets the actual
# leak vector -- human commentary smuggled alongside the artifact under test.
#
# Scope: the *artifact under test* only.  The surrounding learner documentation
# legitimately says "for each defect, state ..." when describing the required
# write-up, so scanning it would be a false positive, not a safety check.
STARTER_FILES=()
while IFS= read -r file; do
    STARTER_FILES+=("$file")
done < <(find ./challenge/fixtures ./gate/fixtures -type f \
    \( -name "*.json" -o -name "*.txt" \) 2>/dev/null)

if [ "${#STARTER_FILES[@]}" -eq 0 ]; then
    echo "[ISOLATION VIOLATION] no scored starter artifact found to audit" >&2
    exit 1
fi

# Fail closed: if the JSON is unreadable the audit must not silently pass.
set +e
LEAK_OUT=$("$PY" - "${STARTER_FILES[@]}" <<'PYEOF'
import json
import re
import sys

# Keys that exist only to explain the puzzle.  None of them belongs in the
# artifact handed to the learner.
BANNED_KEYS = {
    "note", "notes", "hint", "hints", "answer", "answers", "solution",
    "expected", "expected_value", "expected_verdict", "correct",
    "correct_value", "fix", "repair", "root_cause", "defect", "defects",
    "why", "explanation", "rationale", "golden", "reference_answer",
    "should_be", "reason",
}

# Phrases that narrate the defect rather than present the artifact.  Chosen so
# that legitimate task instructions ("repair it, then run make check") pass.
BANNED_PHRASES = [
    "defect", "misclassif", "decoy", "reserved",
    "one encoded field", "is wrong", "are wrong",
    "not executed", "no executed", "comment-only", "comment only",
    "would be here", "does not match", "does not conform",
    "mislabel", "outside the taught", "taught profile", "unfamiliar variant",
    "answer key", "correct value", "root cause", "should be", "must be set",
    "more than one fact", "at least two of these",
]

problems = 0
for path in sys.argv[1:]:
    try:
        with open(path, encoding="utf-8") as handle:
            obj = json.load(handle)
    except Exception as exc:                                   # noqa: BLE001
        print(f"[ISOLATION VIOLATION] scored starter is not readable JSON: {path} ({exc})")
        problems += 1
        continue

    stack = [("$", obj)]
    while stack:
        where, node = stack.pop()
        if isinstance(node, dict):
            for key, value in node.items():
                if key.lower() in BANNED_KEYS:
                    print(f"[ISOLATION VIOLATION] scored starter carries an "
                          f"answer-bearing key: {path} at {where}.{key}")
                    problems += 1
                stack.append((f"{where}.{key}", value))
        elif isinstance(node, list):
            for index, value in enumerate(node):
                stack.append((f"{where}[{index}]", value))
        elif isinstance(node, str):
            lowered = node.lower()
            for phrase in BANNED_PHRASES:
                if phrase in lowered:
                    print(f"[ISOLATION VIOLATION] scored starter narrates its "
                          f"defect: {path} at {where}")
                    print(f"      revealing phrase: {phrase!r}")
                    problems += 1
                    break

print(f"[INFO] audited {len(sys.argv) - 1} scored starter artifact(s) for defect narration",
      file=sys.stderr)
sys.exit(0 if problems == 0 else 1)
PYEOF
)
LEAK_RC=$?
set -e

if [ "$LEAK_RC" -eq 0 ]; then
    echo "[PASS] scored starters carry no defect narration and no answer-bearing keys"
elif [ "$LEAK_RC" -eq 1 ]; then
    printf '%s\n' "$LEAK_OUT" | sed '/^$/d'
    VIOLATIONS=$((VIOLATIONS + 1))
else
    echo "[ISOLATION VIOLATION] starter leak scan failed to run (rc=$LEAK_RC);" >&2
    echo "      an unaudited starter must not be reported as clean." >&2
    printf '%s\n' "$LEAK_OUT" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
fi

# The answer-bearing seed mappings must live only in the reviewer subtree, and
# every starter file must be accompanied by one, so a rotated seed cannot
# silently lose its oracle mapping.
for assessment in challenge gate; do
    case "$assessment" in
        challenge) seed="reviewer/reference/challenge_seed.json" ;;
        gate) seed="reviewer/reference/gate_seed.json" ;;
    esac
    [ -f "$seed" ] || {
        echo "[ISOLATION VIOLATION] hidden seed mapping missing for $assessment: $seed"
        VIOLATIONS=$((VIOLATIONS + 1))
    }
done

if [ "$VIOLATIONS" -eq 0 ]; then
    echo "=== ISOLATION AUDIT PASS: zero learner->reviewer dependencies, zero seed leaks ==="
    exit 0
fi
echo "=== ISOLATION AUDIT FAIL: $VIOLATIONS violation(s) ===" >&2
exit 1
