#!/usr/bin/env bash
# P3-M07 Reviewer-Only Full Authoring Regression.
#
# Runs the complete authoring surface for the Architecture Spine module:
# learner/reviewer isolation, deterministic assessment materialisation,
# learner-safe checks, the adversarial mutation suite, the semantic-oracle
# regression, and -- when a real pinned source tree is supplied -- cross
# validation of every recorded Linux 6.18.50 source reference.
#
# Never called from a learner workflow.  Never merges anything.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M07_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M07_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

echo "##################################################################"
echo "# P3-M07 REVIEWER-CHECK - AUTHORING REGRESSION (REVIEWER-ONLY)   #"
echo "##################################################################"

echo ""
echo "===== [1/6] Learner/Reviewer Isolation Audit ====="
bash reviewer/audit_learner_isolation.sh

echo ""
echo "===== [2/6] Materialise Assessment Fixtures (opaque) ====="
bash reviewer/scripts/generate_m07_assessment_fixtures.sh

echo ""
echo "===== [3/6] Learner-Safe Module Check (no grading logic) ====="
make check

echo ""
echo "===== [4/6] Adversarial Mutation Suite ====="
bash reviewer/test_m07_mutations.sh

echo ""
echo "===== [5/6] Semantic Oracle Regression Suite ====="
bash reviewer/test_m07_oracle_mutations.sh

echo ""
echo "===== [6/6] Real-source cross-validation (pinned Linux 6.18.50) ====="
LINUX_SRC="${LINUX_SRC:-}"
TABLE="reviewer/reference/linux-6.18.50-symbols.json"
EXPECTED_COMMIT=$("$PY" -c 'import json,sys;print(json.load(open(sys.argv[1],encoding="utf-8"))["pin"]["peeled_commit"])' "$TABLE")
if [ -n "$LINUX_SRC" ] && [ -f "$LINUX_SRC/arch/arm/kernel/entry-common.S" ]; then
    LINUX_SRC_ABS=$(cd "$LINUX_SRC" && { pwd -W 2>/dev/null || pwd; })
    echo "[INFO] Linux source tree: $LINUX_SRC_ABS"
    if [ -d "$LINUX_SRC/.git" ]; then
        ACTUAL_COMMIT=$(git -C "$LINUX_SRC" rev-parse HEAD 2>/dev/null || echo unknown)
        echo "[INFO] tree HEAD: $ACTUAL_COMMIT"
        if [ "$ACTUAL_COMMIT" = "$EXPECTED_COMMIT" ]; then
            echo "[PASS] supplied tree is exactly the pinned Linux 6.18.50 commit"
        else
            echo "[FAIL] supplied tree HEAD ($ACTUAL_COMMIT) != pinned commit ($EXPECTED_COMMIT)" >&2
            echo "       a tree at a different commit cannot validate pinned line numbers." >&2
            exit 1
        fi
    else
        echo "[FAIL] supplied tree carries no .git metadata, so pin identity is not provable;" >&2
        echo "       line numbers from an unverified tree must not be accepted." >&2
        exit 1
    fi

    # Positive: every recorded reference must resolve exactly; then prove the
    # checker is fail-closed by making it reject four deliberate corruptions.
    "$PY" reviewer/scripts/verify_linux_source_refs.py \
        --tree "$LINUX_SRC_ABS" --table "$TABLE" --selftest
else
    echo "[NOTE] no Linux source tree supplied (set LINUX_SRC=/path/to/linux-6.18.50):"
    echo "       real-source cross-validation of recorded paths/symbols SKIPPED"
    echo "       (UNVERIFIED on this host)."
    echo "       Canonical baseline: 6.18.50 (tag v6.18.50, peeled commit"
    echo "       $EXPECTED_COMMIT)."
    echo "       Command that closes it:"
    echo "         git clone --depth 1 --branch v6.18.50 --single-branch \\"
    echo "           https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
    echo "         make reviewer-check LINUX_SRC=<clone>"
fi

echo ""
echo "=== P3-M07 REVIEWER-CHECK COMPLETE: ALL STAGES PASSED ==="
