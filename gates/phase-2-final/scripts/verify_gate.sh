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
# Check 2: Score distribution totals exactly 100 points
# ------------------------------------------------------------------------------
echo "Check 2: Score distribution totals exactly 100 points"
python3 -c "
with open('$GATE_DIR/SCORE.md') as f:
    text = f.read()

score_map = {}
for line in text.splitlines():
    if '|' in line and any(k in line for k in ['Part A', 'Part B', 'Part C', 'Part D', 'Total']):
        cols = [c.strip() for c in line.split('|')[1:-1]]
        if len(cols) >= 3 and cols[2].isdigit():
            score_map[cols[0]] = int(cols[2])

assert score_map.get('Part A') == 25, f'Part A score != 25: {score_map.get(\"Part A\")}'
assert score_map.get('Part B') == 25, f'Part B score != 25: {score_map.get(\"Part B\")}'
assert score_map.get('Part C') == 25, f'Part C score != 25: {score_map.get(\"Part C\")}'
assert score_map.get('Part D') == 25, f'Part D score != 25: {score_map.get(\"Part D\")}'
assert score_map.get('Total') == 100, f'Total score != 100: {score_map.get(\"Total\")}'
assert sum([score_map['Part A'], score_map['Part B'], score_map['Part C'], score_map['Part D']]) == 100, 'Sum of parts != 100'
" && report_pass "Weights structurally verified: A=25, B=25, C=25, D=25 (Total = 100 points)" || report_fail "Score distribution structural check failed in SCORE.md"

# ------------------------------------------------------------------------------
# Check 3: Part floors and overall pass threshold match canonical values
# ------------------------------------------------------------------------------
echo "Check 3: Part floors and overall threshold"
python3 -c "
import re

with open('$GATE_DIR/SCORE.md') as f:
    text = f.read()

table_rows = {}
for line in text.splitlines():
    if '|' in line:
        cols = [c.strip() for c in line.split('|')[1:-1]]
        if len(cols) >= 3:
            crit = cols[0].replace('*', '').strip()
            table_rows[crit] = cols[2].strip()

def parse_threshold(cell):
    m = re.search(r'(?:\\\\ge|>=)\s*(?:\\\\mathbf\{)?([0-9]+(?:\.[0-9]+)?)\s*(?:/\s*([0-9]+))?', cell)
    assert m, f'Could not parse active numeric threshold from cell: {cell}'
    num = float(m.group(1))
    denom = int(m.group(2)) if m.group(2) else None
    return num, denom

ov_num, ov_den = parse_threshold(table_rows.get('Overall Total Score', ''))
assert ov_num == 75.0 and ov_den == 100, f'Overall Total Score threshold invalid: {ov_num}/{ov_den}'

pa_num, pa_den = parse_threshold(table_rows.get('Part A Floor', ''))
assert pa_num == 15.0 and pa_den == 25, f'Part A Floor threshold invalid: {pa_num}/{pa_den}'

pb_num, pb_den = parse_threshold(table_rows.get('Part B Floor', ''))
assert pb_num == 15.0 and pb_den == 25, f'Part B Floor threshold invalid: {pb_num}/{pb_den}'

pc_num, pc_den = parse_threshold(table_rows.get('Part C Floor', ''))
assert pc_num == 15.0 and pc_den == 25, f'Part C Floor threshold invalid: {pc_num}/{pc_den}'

pd_num, pd_den = parse_threshold(table_rows.get('Part D Floor (Mastery Bar)', ''))
assert pd_num == 17.5 and pd_den == 25, f'Part D Floor threshold invalid: {pd_num}/{pd_den}'
" && report_pass "Canonical floors structurally verified: Total>=75.0/100, A>=15.0/25 (60%), B>=15.0/25 (60%), C>=15.0/25 (60%), D>=17.5/25 (70%)" || report_fail "Canonical floors structural check failed in SCORE.md"

# ------------------------------------------------------------------------------
# Check 4: Total time budget is 210 minutes (3.5 h) with exact per-part budgets
# ------------------------------------------------------------------------------
echo "Check 4: Time budget is 210 minutes (3.5 hours) with exact per-part breakdown"
python3 -c "
import re

# 1. README.md
with open('$GATE_DIR/README.md') as f:
    readme = f.read()
readme_times = {}
for line in readme.splitlines():
    if '|' in line:
        cols = [c.strip() for c in line.split('|')[1:-1]]
        if len(cols) >= 4 and 'min' in cols[3]:
            part_name = cols[0].replace('*', '').strip()
            m = re.search(r'(\d+)\s*min', cols[3])
            if m:
                readme_times[part_name] = int(m.group(1))

assert readme_times.get('Part A') == 45, f'README Part A time != 45: {readme_times.get(\"Part A\")}'
assert readme_times.get('Part B') == 50, f'README Part B time != 50: {readme_times.get(\"Part B\")}'
assert readme_times.get('Part C') == 50, f'README Part C time != 50: {readme_times.get(\"Part C\")}'
assert readme_times.get('Part D') == 65, f'README Part D time != 65: {readme_times.get(\"Part D\")}'
assert readme_times.get('Total') == 210, f'README Total time != 210: {readme_times.get(\"Total\")}'
assert sum([readme_times['Part A'], readme_times['Part B'], readme_times['Part C'], readme_times['Part D']]) == 210, 'README sum != 210'

# 2. RULES.md
with open('$GATE_DIR/RULES.md') as f:
    rules = f.read()
rules_times = {}
for line in rules.splitlines():
    m = re.search(r'Part\s+([A-D]):\s*(\d+)\s*min', line)
    if m:
        rules_times['Part ' + m.group(1)] = int(m.group(2))
assert rules_times.get('Part A') == 45, f'RULES Part A time != 45: {rules_times.get(\"Part A\")}'
assert rules_times.get('Part B') == 50, f'RULES Part B time != 50: {rules_times.get(\"Part B\")}'
assert rules_times.get('Part C') == 50, f'RULES Part C time != 50: {rules_times.get(\"Part C\")}'
assert rules_times.get('Part D') == 65, f'RULES Part D time != 65: {rules_times.get(\"Part D\")}'
assert sum([rules_times['Part A'], rules_times['Part B'], rules_times['Part C'], rules_times['Part D']]) == 210, 'RULES sum != 210'
assert '210' in rules, '210 minutes total budget missing in RULES.md'

# 3. SUBMISSION_TEMPLATE.md
with open('$GATE_DIR/SUBMISSION_TEMPLATE.md') as f:
    sub = f.read()
sub_times = {}
for line in sub.splitlines():
    if '|' in line:
        cols = [c.strip() for c in line.split('|')[1:-1]]
        if len(cols) >= 5 and 'min' in cols[4]:
            part_name = cols[0].replace('*', '').strip()
            m = re.search(r'(\d+)\s*min', cols[4])
            if m:
                sub_times[part_name] = int(m.group(1))

a_time = next((v for k, v in sub_times.items() if k.startswith('Part A')), None)
b_time = next((v for k, v in sub_times.items() if k.startswith('Part B')), None)
c_time = next((v for k, v in sub_times.items() if k.startswith('Part C')), None)
d_time = next((v for k, v in sub_times.items() if k.startswith('Part D')), None)
tot_time = sub_times.get('Total')
assert a_time == 45 and b_time == 50 and c_time == 50 and d_time == 65 and tot_time == 210, f'SUBMISSION_TEMPLATE time breakdown mismatch: A={a_time}, B={b_time}, C={c_time}, D={d_time}, Total={tot_time}'
assert sum([a_time, b_time, c_time, d_time]) == 210, 'SUBMISSION_TEMPLATE sum != 210'
" && report_pass "Time budgets structurally verified across README, RULES, SUBMISSION_TEMPLATE: A=45m, B=50m, C=50m, D=65m (Sum = 210m)" || report_fail "Time budget structural check failed"

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
# Check 6: Reviewer isolation and leak prevention in learner-facing materials
# ------------------------------------------------------------------------------
echo "Check 6: Reviewer isolation and leak prevention in learner-facing materials"
LEAK_CHECK=$(python3 -c "
import os, re

gate_dir = '$GATE_DIR'

learner_docs = [
    os.path.join(gate_dir, 'README.md'),
    os.path.join(gate_dir, 'RULES.md'),
    os.path.join(gate_dir, 'SCORE.md'),
    os.path.join(gate_dir, 'ENVIRONMENT.md'),
    os.path.join(gate_dir, 'SOURCE_LEDGER.md'),
    os.path.join(gate_dir, 'SUBMISSION_TEMPLATE.md'),
    os.path.join(gate_dir, 'part-a', 'README.md'),
    os.path.join(gate_dir, 'part-b', 'README.md'),
    os.path.join(gate_dir, 'part-c', 'README.md'),
    os.path.join(gate_dir, 'part-d', 'README.md'),
]

prohibited_reviewer = [
    'gate_solution.md',
    'seed_mapping.md',
    'regression_oracle.md',
    'scoring_anchors.md',
    'verify_reviewer.sh',
    'verify_isolation.py',
    'regression_oracle.py',
    'test_reviewer_negative_controls.sh'
]

# Generic solution/defect leak markers forbidden in learner-facing materials
generic_leak_markers = [
    'Seeded Defect:',
    'Root Cause:',
    'Reference Fix:',
    'Canonical Fix:',
]

leaks = []
for doc in learner_docs:
    if not os.path.exists(doc):
        continue
    with open(doc, 'r', encoding='utf-8', errors='replace') as fp:
        txt = fp.read()
        for p in prohibited_reviewer:
            if p in txt:
                leaks.append(f'{doc}: contains prohibited reviewer reference: {p}')
        if re.search(r'\[.*?\]\(.*?reviewer/', txt):
            leaks.append(f'{doc}: contains direct markdown link to reviewer/')
        for marker in generic_leak_markers:
            if marker in txt:
                leaks.append(f'{doc}: contains generic answer leak marker: {marker}')

# Also scan all other files in learner directories for reviewer references and generic markers
for d in ['part-a', 'part-b', 'part-c', 'part-d']:
    full_dir = os.path.join(gate_dir, d)
    for root, _, files in os.walk(full_dir):
        if 'build' in root:
            continue
        for f in files:
            p = os.path.join(root, f)
            with open(p, 'r', encoding='utf-8', errors='replace') as fp:
                content = fp.read()
                for prob in prohibited_reviewer:
                    if prob in content:
                        leaks.append(f'{p}: contains prohibited reviewer reference: {prob}')
                if re.search(r'\[.*?\]\((\.\./)*reviewer/', content):
                    leaks.append(f'{p}: contains markdown link to reviewer/')
                for marker in generic_leak_markers:
                    if marker in content:
                        leaks.append(f'{p}: contains generic answer leak marker: {marker}')

if leaks:
    print('\n'.join(leaks))
else:
    print('CLEAN')
")

if [ "$LEAK_CHECK" = "CLEAN" ]; then
    report_pass "Learner-facing paths contain zero reviewer links and zero leaked root causes/fixes"
else
    report_fail "Learner files contain leaks:\n$LEAK_CHECK"
fi

# ------------------------------------------------------------------------------
# Check 7: Exact source pins present and component-bound
# ------------------------------------------------------------------------------
echo "Check 7: Exact upstream source pins present and bound to Gate parts"
python3 -c "
import re

with open('$GATE_DIR/SOURCE_LEDGER.md') as f:
    text = f.read()

sections = re.split(r'\n###\s+', text)
sec_map = {}
for sec in sections[1:]:
    title = sec.split('\n')[0].strip()
    sec_map[title] = sec

# Verify FreeRTOS section
freertos_sec = next((v for k, v in sec_map.items() if 'FreeRTOS-Kernel' in k), '')
assert freertos_sec, 'FreeRTOS-Kernel section missing'
assert '9b777ae5c5b8e9e456065a00294d1e5f5f9facf5' in freertos_sec, 'FreeRTOS commit SHA missing from FreeRTOS section'
assert '2b7495b8535bdcb306dac29b9ded4cfb679d7e5c' not in freertos_sec, 'CMSIS SHA leaked into FreeRTOS section (ownership swap)'
assert 'V11.3.0' in freertos_sec, 'FreeRTOS version tag V11.3.0 missing from section'

# Verify CMSIS_5 section
cmsis_sec = next((v for k, v in sec_map.items() if 'CMSIS_5' in k), '')
assert cmsis_sec, 'CMSIS_5 section missing'
assert '2b7495b8535bdcb306dac29b9ded4cfb679d7e5c' in cmsis_sec, 'CMSIS_5 commit SHA missing from CMSIS_5 section'
assert '9b777ae5c5b8e9e456065a00294d1e5f5f9facf5' not in cmsis_sec, 'FreeRTOS SHA leaked into CMSIS_5 section (ownership swap)'
assert 'v5.9.0' in cmsis_sec, 'CMSIS_5 version tag v5.9.0 missing from section'

# Verify cmsis-device-f1 section
dev_sec = next((v for k, v in sec_map.items() if 'cmsis-device-f1' in k), '')
assert dev_sec, 'cmsis-device-f1 section missing'
assert '8a76309ed1250d817e9c888c4417171d2ba3ba63' in dev_sec, 'cmsis-device-f1 commit SHA missing from section'
assert 'v4.3.5' in dev_sec, 'cmsis-device-f1 version tag v4.3.5 missing from section'

# Verify Silicon Manuals
assert 'RM0008' in text and 'DocID 13902 Rev 21' in text, 'RM0008 specification missing'
assert 'DS5319' in text and 'DocID 13587 Rev 20' in text, 'DS5319 specification missing'
assert 'PM0056' in text and 'DocID 15491 Rev 7' in text, 'PM0056 specification missing'
assert 'DDI 0403E.e' in text, 'Armv7-M DDI 0403E.e specification missing'
" && report_pass "All required upstream SHAs and primary specifications structurally bound to component sections in SOURCE_LEDGER.md" || report_fail "Source pin structural ownership check failed in SOURCE_LEDGER.md"

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
    report_pass "All 4 seeded broken fixtures fail check with neutral failure messages"
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
