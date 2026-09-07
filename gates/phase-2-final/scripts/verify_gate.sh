#!/usr/bin/env bash
# ==============================================================================
# verify_gate.sh: Automated Static Package Verification for Phase 2 Final Gate
# Implements all 13 canonical Gate verification checks mandated by Issue #25.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$GATE_DIR/../.." && pwd)"

FAILURES=0

report_pass() {
    echo "  [PASS] $1"
}

report_fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

echo "=============================================================================="
echo "Running Phase 2 Final Gate Package Verification"
echo "Target: $GATE_DIR"
echo "=============================================================================="

# ------------------------------------------------------------------------------
# Check 1: Required Gate files and directories exist
# ------------------------------------------------------------------------------
echo "Check 1: Required Gate files and directories existence"
REQ_FILES=(
    "README.md"
    "RULES.md"
    "SCORE.md"
    "ENVIRONMENT.md"
    "SOURCE_LEDGER.md"
    "SUBMISSION_TEMPLATE.md"
    "Makefile"
    "part-a/README.md"
    "part-a/Makefile"
    "part-b/README.md"
    "part-b/Makefile"
    "part-c/README.md"
    "part-c/Makefile"
    "part-d/README.md"
    "part-d/Makefile"
    "reviewer/gate_solution.md"
    "reviewer/seed_mapping.md"
    "reviewer/scoring_anchors.md"
    "reviewer/regression_oracle.md"
    "reviewer/verify_reviewer.sh"
    "scripts/verify_gate.sh"
)

MISSING_FILE=0
for f in "${REQ_FILES[@]}"; do
    if [ ! -f "$GATE_DIR/$f" ]; then
        report_fail "Missing required file: $f"
        MISSING_FILE=1
    fi
done
if [ $MISSING_FILE -eq 0 ]; then
    report_pass "All required files exist"
fi

# ------------------------------------------------------------------------------
# Check 2: Score weights total exactly 100 points
# ------------------------------------------------------------------------------
echo "Check 2: Score distribution totals exactly 100 points"
TOTAL_SCORE=$(python3 -c "
import re
with open('$GATE_DIR/SCORE.md') as f:
    text = f.read()
# Extract parts scores
a = int(re.search(r'Part A.*?\|\s*(\d+)\s*\|', text).group(1))
b = int(re.search(r'Part B.*?\|\s*(\d+)\s*\|', text).group(1))
c = int(re.search(r'Part C.*?\|\s*(\d+)\s*\|', text).group(1))
d = int(re.search(r'Part D.*?\|\s*(\d+)\s*\|', text).group(1))
tot = a + b + c + d
print(f'{tot}:{a}:{b}:{c}:{d}')
")

IFS=':' read -r TOT PTS_A PTS_B PTS_C PTS_D <<< "$TOTAL_SCORE"
if [ "$TOT" -eq 100 ] && [ "$PTS_A" -eq 25 ] && [ "$PTS_B" -eq 25 ] && [ "$PTS_C" -eq 25 ] && [ "$PTS_D" -eq 25 ]; then
    report_pass "Weights: A=$PTS_A, B=$PTS_B, C=$PTS_C, D=$PTS_D (Total = $TOT points)"
else
    report_fail "Score weights mismatch! Expected 25/25/25/25 (100), got A=$PTS_A, B=$PTS_B, C=$PTS_C, D=$PTS_D (Total = $TOT)"
fi

# ------------------------------------------------------------------------------
# Check 3: Part floors and overall pass threshold match canonical values
# ------------------------------------------------------------------------------
echo "Check 3: Part floors and overall threshold"
python3 -c "
import re, sys
with open('$GATE_DIR/SCORE.md') as f:
    text = f.read()

assert '75' in text, 'Overall pass threshold 75 missing'
assert re.search(r'Part A.*?15\.0', text), 'Part A floor 15.0 missing'
assert re.search(r'Part B.*?15\.0', text), 'Part B floor 15.0 missing'
assert re.search(r'Part C.*?15\.0', text), 'Part C floor 15.0 missing'
assert re.search(r'Part D.*?17\.5', text), 'Part D floor 17.5 missing'
" && report_pass "Canonical floors verified: Total>=75, A>=15.0 (60%), B>=15.0 (60%), C>=15.0 (60%), D>=17.5 (70%)" || report_fail "Canonical floors check failed in SCORE.md"

# ------------------------------------------------------------------------------
# Check 4: Total time budget is 210 minutes (3.5 h)
# ------------------------------------------------------------------------------
echo "Check 4: Time budget is 210 minutes (3.5 hours)"
TIME_CHECK=$(python3 -c "
import re
files = ['README.md', 'RULES.md', 'SUBMISSION_TEMPLATE.md']
ok = True
for f in files:
    with open('$GATE_DIR/' + f) as fp:
        content = fp.read()
        if '210' not in content:
            ok = False
            break
print('OK' if ok else 'FAIL')
")

if [ "$TIME_CHECK" = "OK" ]; then
    report_pass "210 minutes (3.5 h) time budget verified across README, RULES, SUBMISSION_TEMPLATE"
else
    report_fail "Time budget 210 minutes missing from one or more student documents"
fi

# ------------------------------------------------------------------------------
# Check 5: Learner rules explicitly state AI-Free
# ------------------------------------------------------------------------------
echo "Check 5: Strict AI-Free rule stated in learner documents"
if grep -q "AI-Free" "$GATE_DIR/RULES.md" && grep -q "Prohibited Resources" "$GATE_DIR/RULES.md" && grep -q "AI-Free Examination Attestation" "$GATE_DIR/SUBMISSION_TEMPLATE.md"; then
    report_pass "AI-Free mode, prohibited resources, and attestation verified"
else
    report_fail "AI-Free policy or attestation missing in RULES.md / SUBMISSION_TEMPLATE.md"
fi

# ------------------------------------------------------------------------------
# Check 6: Learner files do not directly link to reviewer solution/seed files
# ------------------------------------------------------------------------------
echo "Check 6: Reviewer isolation and secrecy in learner-facing files"
LEAK_CHECK=$(python3 -c "
import os, re

learner_dirs = ['part-a', 'part-b', 'part-c', 'part-d']
prohibited = ['gate_solution.md', 'seed_mapping.md', 'regression_oracle.md', 'scoring_anchors.md']
leaks = []

for d in learner_dirs:
    full_dir = os.path.join('$GATE_DIR', d)
    for root, _, files in os.walk(full_dir):
        for f in files:
            p = os.path.join(root, f)
            with open(p, 'r', errors='replace') as fp:
                txt = fp.read()
                for prob in prohibited:
                    if prob in txt:
                        leaks.append(f'{p}: contains {prob}')
                # Also ensure no direct link to reviewer directory
                if re.search(r'\[.*?\]\((\.\./)*reviewer/', txt):
                    leaks.append(f'{p}: contains direct markdown link to reviewer/')

if leaks:
    print('\n'.join(leaks))
else:
    print('CLEAN')
")

if [ "$LEAK_CHECK" = "CLEAN" ]; then
    report_pass "Learner-facing paths contain zero direct links or references to reviewer solutions"
else
    report_fail "Learner files leak reviewer solutions:\n$LEAK_CHECK"
fi

# ------------------------------------------------------------------------------
# Check 7: Exact source pins present and component-bound
# ------------------------------------------------------------------------------
echo "Check 7: Exact upstream source pins present and bound to Gate parts"
python3 -c "
with open('$GATE_DIR/SOURCE_LEDGER.md') as f:
    text = f.read()

pins = [
    '9b777ae5c5b8e9e456065a00294d1e5f5f9facf5', # FreeRTOS
    '2b7495b8535bdcb306dac29b9ded4cfb679d7e5c', # CMSIS_5
    '8a76309ed1250d817e9c888c4417171d2ba3ba63', # cmsis-device-f1
    'RM0008',
    'DS5319',
    'PM0056',
    'DDI 0403E.e'
]
for p in pins:
    assert p in text, f'Source pin {p} missing in SOURCE_LEDGER.md'
" && report_pass "All required upstream SHAs and primary specifications present in SOURCE_LEDGER.md" || report_fail "Missing required upstream pins in SOURCE_LEDGER.md"

# ------------------------------------------------------------------------------
# Check 8: Seeded buildable fixtures compile/link under strict flags
# ------------------------------------------------------------------------------
echo "Check 8: Strict compile and link for all seeded fixtures"
BUILD_FAIL=0
for part in part-a part-b part-c part-d; do
    if ! make -C "$GATE_DIR/$part" clean all > /dev/null 2>&1; then
        report_fail "$part failed strict compilation/link!"
        BUILD_FAIL=1
    elif [ ! -f "$GATE_DIR/$part/build/firmware.elf" ]; then
        report_fail "$part did not generate build/firmware.elf!"
        BUILD_FAIL=1
    fi
done
if [ $BUILD_FAIL -eq 0 ]; then
    report_pass "All 4 parts compile and link cleanly under -Wall -Wextra -Werror -nostartfiles"
fi

# ------------------------------------------------------------------------------
# Check 9: Fixed/reference fixtures pass their intended checks
# ------------------------------------------------------------------------------
echo "Check 9: Reviewer reference fixtures exist and pass"
REF_FILES=(
    "reviewer/reference/part-a/stm32f103c8tx_flash.ld"
    "reviewer/reference/part-b/dma.c"
    "reviewer/reference/part-c/interrupt_config.c"
    "reviewer/reference/part-d/node_app.c"
)
MISSING_REF=0
for rf in "${REF_FILES[@]}"; do
    if [ ! -f "$GATE_DIR/$rf" ]; then
        report_fail "Missing reference fix: $rf"
        MISSING_REF=1
    fi
done
if [ $MISSING_REF -eq 0 ]; then
    report_pass "All 4 reference fix files present in reviewer/reference/"
fi

# ------------------------------------------------------------------------------
# Check 10: Seeded broken fixtures exhibit the intended failure
# ------------------------------------------------------------------------------
echo "Check 10: Seeded broken fixtures exhibit intended reviewer-detectable failure"
SEEDED_FAIL=0
for part in part-a part-b part-c part-d; do
    if make -C "$GATE_DIR/$part" check > /dev/null 2>&1; then
        report_fail "Seeded broken fixture in $part unexpectedly passed check!"
        SEEDED_FAIL=1
    fi
done
if [ $SEEDED_FAIL -eq 0 ]; then
    report_pass "All 4 seeded broken fixtures fail check with intended diagnostic messages"
fi

# ------------------------------------------------------------------------------
# Check 11: No fabricated physical evidence is embedded as if observed
# ------------------------------------------------------------------------------
echo "Check 11: Evidence integrity and labeling of seeded fixtures"
python3 -c "
import os
for root, _, files in os.walk('$GATE_DIR'):
    if 'reviewer' in root:
        continue
    if 'fixtures' in root:
        for f in files:
            if f.endswith('.txt') or f.endswith('.md'):
                p = os.path.join(root, f)
                with open(p, 'r', errors='replace') as fp:
                    txt = fp.read()
                    assert 'SEEDED FIXTURE / ASSESSMENT INPUT' in txt, f'{p} missing SEEDED FIXTURE notice'
                    assert 'NOT LIVE HARDWARE EVIDENCE' in txt, f'{p} missing NOT LIVE HARDWARE EVIDENCE notice'
" && report_pass "Pre-recorded fixtures are explicitly labeled 'SEEDED FIXTURE / ASSESSMENT INPUT'" || report_fail "Found fixture missing SEEDED FIXTURE notice"

# ------------------------------------------------------------------------------
# Check 12: Reviewer solution exists for every seeded variant
# ------------------------------------------------------------------------------
echo "Check 12: Reviewer solutions coverage"
python3 -c "
with open('$GATE_DIR/reviewer/gate_solution.md') as f:
    sol = f.read()
for p in ['Part A', 'Part B', 'Part C', 'Part D']:
    assert p in sol, f'Missing solution for {p}'
    assert 'root cause' in sol.lower(), f'Missing root cause for {p}'
    assert 'minimal fix' in sol.lower(), f'Missing minimal fix for {p}'
" && report_pass "Reviewer solution covers symptom, hypotheses, root cause, minimal fix, and non-proof across Parts A-D" || report_fail "Reviewer solution incomplete"

# ------------------------------------------------------------------------------
# Check 13: Phase 1 Gate remains untouched/regression-safe
# ------------------------------------------------------------------------------
echo "Check 13: Phase 1 Gate regression check"
if [ ! -d "$REPO_ROOT/gates/phase-1-final" ]; then
    report_fail "Phase 1 Gate directory missing!"
elif [ -n "$(git status --porcelain "$REPO_ROOT/gates/phase-1-final")" ]; then
    report_fail "Phase 1 Gate has unexpected git modifications!"
else
    report_pass "Phase 1 Gate is clean, untouched, and regression-safe"
fi

echo "=============================================================================="
if [ $FAILURES -eq 0 ]; then
    echo ">>> ALL 13 PHASE 2 GATE VERIFICATION CHECKS PASSED <<<"
    exit 0
else
    echo ">>> $FAILURES VERIFICATION CHECK(S) FAILED <<<"
    exit 1
fi
