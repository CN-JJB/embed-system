<!--
MANDATORY:
1. Read root AGENTS.md before completing this PR.
2. If you are the Executor, complete every applicable section below.
3. Do not delete the verification boundary because tests "passed".
4. Executor must NOT merge this PR.
-->

Closes #

## Executor Handoff Report

### 1. Scope Delivered
- Issue:
- In-scope work completed:
- Explicitly out of scope / not touched:
- Scope deviations, if any:

### 2. What Changed
- Architecture / implementation:
- Important files/directories:
- Labs / challenges / faults / Gates:
- Validators / reviewer material:
- Source/version/license changes:

### 3. Problems Encountered and How They Were Solved

#### Problem 1
- Symptom / obstacle:
- Hypotheses considered:
- Evidence inspected:
- Root cause:
- Fix chosen:
- Regression / follow-up:

<!-- Add additional problems as needed. If none were meaningful, say so explicitly. -->

### 4. Verification Actually Performed

#### Test / Command 1
- Command:
- Result:
- Proves:
- Does NOT prove:

<!-- Repeat for meaningful checks. Do not report commands that were not actually run. -->

### 5. Verification Boundary

| Evidence | Status | Basis | Does not prove |
|---|---|---|---|
| Source/version identity |  |  |  |
| Host/unit tests |  |  |  |
| Target compile/link |  |  |  |
| Static ELF/disassembly |  |  |  |
| Target flash/run |  |  |  |
| Live GDB/registers |  |  |  |
| Physical waveform/measurement |  |  |  |

Allowed status values:
- VERIFIED
- PARTIALLY VERIFIED
- UNVERIFIED

### 6. Sources / Toolchain / Environment
- Host OS/environment:
- Compiler:
- Binutils:
- GDB:
- Canonical toolchain baseline:
- Upstream tags/commits/revisions:
- Important source paths:
- License/source-origin notes:

### 7. Known Limitations / Residual Risks
- Remaining hardware-only items:
- Portability assumptions:
- Validator/test limitations:
- Areas that deserve Leader attention:

### 8. Git / PR State
- Branch:
- Current remote HEAD:
- PR:
- Issue closing contract:
- Leader commits preserved:
- Merge performed by Executor: **NO**

### 9. Leader Review Request
- Ready for review:
- Please inspect especially:
- Unresolved Leader decision:

---

<!--
For S2/S3 rework, update the same PR and add a new section:

## Executor Rework Handoff — Round N
- Leader rework comment/review addressed:
- Item-by-item closure:
- Problems encountered during rework:
- Verification rerun:
- Leader commits preserved:
- Current remote HEAD:
- Remaining unresolved items:

The handoff must describe the latest remote revision, not the original submission.
-->
