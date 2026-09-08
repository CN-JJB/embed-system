#!/usr/bin/env python3
"""
verify_isolation.py: Reviewer-Isolated Leakage & Answer Key Audit.
Scans all learner-visible files (Markdown, C, H, Assembly, Linker scripts,
Makefiles, Python/Shell scripts, and Fixture text) to prove zero disclosure of
seed-specific root causes, expected register bit values, canonical fixes,
or reviewer documentation.

Hardened for Leader Rework Round 3:
- Covers exact seed secrets and paraphrased diagnostic leak regexes.
- Prohibits causal explanations and solution decodes in learner fixtures.
"""
import os
import sys
import re

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GATE_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))

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

generic_leak_markers = [
    'Seeded Defect:',
    'Root Cause:',
    'Reference Fix:',
    'Canonical Fix:',
]

# Exact substring secrets
seed_specific_secrets = [
    # Part A Secrets (Data relocation / LMA displacement / _sidata explanation)
    '_sidata points to _etext',
    'sidata points to etext',
    '_sidata should be LOADADDR',
    'rodata copied to data',
    'copies .rodata into .data',
    'empty data copy',
    '_edata before .data',
    '_edata == _sdata',
    'LMA mismatch',
    # Part B Secrets (DMA CCR CIRC / MINC)
    'missing DMA_CCR_CIRC',
    'omitted DMA_CCR_CIRC',
    'omit DMA_CCR_CIRC',
    'circular mode omitted',
    'circular mode disabled',
    'single-shot stall',
    'missing DMA_CCR_MINC',
    'destination address never increments',
    # Part C Secrets (Priority byte / NVIC encoding / Syscall boundary)
    'priority byte 0x40',
    'priority byte 0x30',
    'logical priority 4',
    'logical priority 3',
    'EXTI0 priority is 4',
    'EXTI0 priority set to 4',
    'higher urgency than configMAX_SYSCALL',
    'violates configMAX_SYSCALL',
    'violates syscall boundary',
    # Part D Secrets (Unreleased mutex / lock leak / wrong semaphore)
    'releases wrong semaphore',
    'releases xLogBufferLock instead of',
    'fails to release xSensorBusLock',
    'unreleased xSensorBusLock',
    'lock is not released',
    'held synchronization resource',
    'synchronization resource is not released',
    'unreleased mutex',
    'lock leak',
    'mutex leak',
    'task_storage forgets to unlock',
    'task_storage never releases',
    'AB-BA deadlock',
]

# Paraphrased answer leak regex patterns
paraphrased_leak_regexes = [
    r'sidata.*points to.*etext',
    r'copies.*rodata.*into.*data',
    r'circular mode.*not enabled',
    r'circular mode.*omitted',
    r'channel halts.*after.*block',
    r'priority.*byte.*0x40',
    r'priority.*below.*syscall',
    r'urgency.*violat.*syscall',
    r'lock.*is not released',
    r'resource.*is not released',
    r'fails to release.*lock',
    r'held mutex.*blocks',
]

learner_docs = [
    os.path.join(GATE_DIR, 'README.md'),
    os.path.join(GATE_DIR, 'RULES.md'),
    os.path.join(GATE_DIR, 'SCORE.md'),
    os.path.join(GATE_DIR, 'ENVIRONMENT.md'),
    os.path.join(GATE_DIR, 'SOURCE_LEDGER.md'),
    os.path.join(GATE_DIR, 'SUBMISSION_TEMPLATE.md'),
]

leaks = []

def audit_file_content(path, content, check_reviewer=True, check_generic=True):
    if check_reviewer:
        for p in prohibited_reviewer:
            if p in content:
                leaks.append(f"{path}: contains prohibited reviewer reference: {p}")
        if re.search(r'\[.*?\]\((\.\./)*reviewer/', content):
            leaks.append(f"{path}: contains direct markdown link to reviewer/")
    if check_generic:
        for marker in generic_leak_markers:
            if marker in content:
                leaks.append(f"{path}: contains generic answer leak marker: {marker}")
    for secret in seed_specific_secrets:
        if secret.lower() in content.lower():
            leaks.append(f"{path}: leaks seed-specific secret: {secret}")
    for pattern in paraphrased_leak_regexes:
        if re.search(pattern, content, re.IGNORECASE):
            leaks.append(f"{path}: matches paraphrased answer leak pattern: {pattern}")

# 1. Scan learner top-level docs
for doc in learner_docs:
    if not os.path.exists(doc):
        continue
    with open(doc, 'r', encoding='utf-8', errors='replace') as fp:
        audit_file_content(doc, fp.read(), check_reviewer=True, check_generic=True)

# 2. Scan learner part directories (part-a, part-b, part-c, part-d)
for d in ['part-a', 'part-b', 'part-c', 'part-d']:
    full_dir = os.path.join(GATE_DIR, d)
    for root, _, files in os.walk(full_dir):
        if 'build' in root:
            continue
        for f in files:
            p = os.path.join(root, f)
            with open(p, 'r', encoding='utf-8', errors='replace') as fp:
                audit_file_content(p, fp.read(), check_reviewer=True, check_generic=True)

# 3. Scan learner scripts (scripts/) - must not have links to reviewer/ or seed secrets
scripts_dir = os.path.join(GATE_DIR, 'scripts')
for root, _, files in os.walk(scripts_dir):
    for f in files:
        p = os.path.join(root, f)
        with open(p, 'r', encoding='utf-8', errors='replace') as fp:
            content = fp.read()
            if re.search(r'\[.*?\]\((\.\./)*reviewer/', content):
                leaks.append(f"{p}: contains direct markdown link to reviewer/")
            for secret in seed_specific_secrets:
                if secret.lower() in content.lower():
                    leaks.append(f"{p}: leaks seed-specific secret: {secret}")
            for pattern in paraphrased_leak_regexes:
                if re.search(pattern, content, re.IGNORECASE):
                    leaks.append(f"{p}: matches paraphrased answer leak pattern: {pattern}")

if leaks:
    print(f"FAILED: Found {len(leaks)} isolation leak(s):")
    for leak in leaks:
        print(f"  [LEAK] {leak}")
    sys.exit(1)
else:
    print("PASS: Reviewer isolation audit verified clean across all learner-visible files.")
    sys.exit(0)
