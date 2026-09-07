#!/usr/bin/env python3
"""
verify_isolation.py: Reviewer-Isolated Leakage & Answer Key Audit.
Scans all learner-visible files to prove zero disclosure of seed-specific root causes,
expected register bit values, canonical fixes, or reviewer documentation.
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

# Seed-specific secret strings that MUST NEVER appear in learner-visible files
seed_specific_secrets = [
    # Part A Secrets (Data relocation / empty copy range / LMA displacement)
    '_edata before .data',
    '_edata placed before',
    '_edata == _sdata',
    'empty data copy',
    'zero-length data copy',
    '0-byte data copy',
    '0 bytes copied',
    'empty .data relocation',
    'corrupted LMA',
    'LMA mismatch',
    # Part B Secrets (DMA CCR MINC / CIRC)
    'missing DMA_CCR_MINC',
    'omitted DMA_CCR_MINC',
    'omit DMA_CCR_MINC',
    'memory increment omitted',
    'lacks MINC',
    'missing MINC',
    'pointer stagnation',
    'destination address never increments',
    'only slot 0 written',
    'only slot 0 updated',
    'missing DMA_CCR_CIRC',
    'circular mode omitted',
    'single-shot stall',
    'circular mode disabled',
    # Part C Secrets (Priority byte / NVIC encoding / Syscall boundary)
    'priority byte 0x30',
    'priority byte 0x00',
    'logical priority 3',
    'logical priority 0',
    'EXTI0 priority is 3',
    'EXTI0 priority set to 3',
    'higher urgency than configMAX_SYSCALL',
    'violates configMAX_SYSCALL',
    'violates syscall boundary',
    'BASEPRI (0x50) fails',
    # Part D Secrets (Unreleased mutex / lock leak / AB-BA)
    'missing xSemaphoreGive',
    'omitted xSemaphoreGive',
    'fails to release xSensorBusLock',
    'unreleased xSensorBusLock',
    'unreleased mutex',
    'lock leak',
    'mutex leak',
    'task_storage forgets to unlock',
    'task_storage never releases',
    'AB-BA deadlock',
    'inverted lock',
    'circular wait deadlock',
    'xTelemetryBufferLock',
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

# 1. Scan learner top-level docs
for doc in learner_docs:
    if not os.path.exists(doc):
        continue
    with open(doc, 'r', encoding='utf-8', errors='replace') as fp:
        txt = fp.read()
        for p in prohibited_reviewer:
            if p in txt:
                leaks.append(f"{doc}: contains prohibited reviewer reference: {p}")
        if re.search(r'\[.*?\]\(.*?reviewer/', txt):
            leaks.append(f"{doc}: contains direct markdown link to reviewer/")
        for marker in generic_leak_markers:
            if marker in txt:
                leaks.append(f"{doc}: contains generic answer leak marker: {marker}")
        for secret in seed_specific_secrets:
            if secret.lower() in txt.lower():
                leaks.append(f"{doc}: leaks seed-specific secret: {secret}")

# 2. Scan learner part directories (part-a, part-b, part-c, part-d)
for d in ['part-a', 'part-b', 'part-c', 'part-d']:
    full_dir = os.path.join(GATE_DIR, d)
    for root, _, files in os.walk(full_dir):
        if 'build' in root:
            continue
        for f in files:
            p = os.path.join(root, f)
            with open(p, 'r', encoding='utf-8', errors='replace') as fp:
                content = fp.read()
                for prob in prohibited_reviewer:
                    if prob in content:
                        leaks.append(f"{p}: contains prohibited reviewer reference: {prob}")
                if re.search(r'\[.*?\]\((\.\./)*reviewer/', content):
                    leaks.append(f"{p}: contains markdown link to reviewer/")
                for marker in generic_leak_markers:
                    if marker in content:
                        leaks.append(f"{p}: contains generic answer leak marker: {marker}")
                for secret in seed_specific_secrets:
                    if secret.lower() in content.lower():
                        leaks.append(f"{p}: leaks seed-specific secret: {secret}")

# 3. Scan learner scripts (scripts/) - must not have links to reviewer/ or seed secrets
scripts_dir = os.path.join(GATE_DIR, 'scripts')
for root, _, files in os.walk(scripts_dir):
    for f in files:
        p = os.path.join(root, f)
        with open(p, 'r', encoding='utf-8', errors='replace') as fp:
            content = fp.read()
            if re.search(r'\[.*?\]\((\.\./)*reviewer/', content):
                leaks.append(f"{p}: contains markdown link to reviewer/")
            for secret in seed_specific_secrets:
                if secret.lower() in content.lower():
                    leaks.append(f"{p}: leaks seed-specific secret: {secret}")

if leaks:
    print(f"FAILED: Found {len(leaks)} isolation leak(s):")
    for leak in leaks:
        print(f"  [LEAK] {leak}")
    sys.exit(1)
else:
    print("PASS: Reviewer isolation audit verified clean across all learner-visible files.")
    sys.exit(0)
