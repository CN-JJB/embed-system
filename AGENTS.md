# AGENTS.md

> **MANDATORY PRE-WORK RULE**
>
> Any AI agent, coding agent, research agent, reviewer, or automation working in this repository MUST read this file **before editing, researching, validating, reviewing, or opening/updating a Pull Request**.
>
> Then read the assigned GitHub Issue and every canonical document linked by that Issue.

This repository uses a strict role-separated workflow:

```text
Leader Issue
→ Executor implementation/research branch
→ Executor Pull Request + Handoff Report
→ Leader Review
→ S0/S1 Leader direct fixes OR S2/S3 Executor rework
→ Leader canonical decision / merge
```

No agent may silently change roles during a task.

---

## 1. Role Selection

### Leader / Editor-in-Chief / Technical Reviewer

You are the **Leader** only when the task explicitly assigns you Leader/reviewer/editorial authority.

The Leader owns:

- curriculum architecture;
- task decomposition;
- canonical technical contracts;
- GitHub Issue specifications;
- source/version/evidence review;
- technical and teaching review;
- assessment validity;
- S0/S1 direct fixes;
- S2/S3 rework decisions;
- canonical inclusion;
- final merge.

The Leader may edit an Executor branch for S0/S1 corrections.

The Leader does **not** fabricate missing implementation evidence.

### Executor / Implementation Agent

You are an **Executor** when you are asked to claim/read an Issue and implement, research, draft, validate, or rework it.

The Executor owns:

- reading this file before work;
- reading the full assigned Issue;
- reading linked canonical design/source-policy documents;
- implementing only the assigned scope;
- preserving Leader commits during rework;
- source/version/license integrity;
- running appropriate verification;
- reporting evidence honestly;
- creating/updating the assigned PR;
- maintaining a complete **Executor Handoff Report** in that PR;
- waiting for Leader Review.

The Executor MUST NOT:

- merge its own PR;
- decide that its work is canonical;
- self-approve or self-promote to Leader;
- silently expand scope;
- replace Leader S2/S3 requirements with a different interpretation;
- claim hardware/GDB/waveform/runtime evidence that was not actually captured.

### Learner / Owner / Dispatcher

The Learner/Owner/Dispatcher:

- performs learning and real experiments;
- dispatches Leader-authored Issue prompts to Executor agents;
- records genuine target evidence where applicable;
- does not replace Leader technical review.

---

## 2. Instruction Precedence

For an Executor, use this order:

1. repository safety/evidence rules in this file;
2. latest Leader review/rework comment on the assigned Issue/PR;
3. assigned GitHub Issue;
4. canonical documents on `main` linked by the Issue;
5. relevant `.editorial/` policies;
6. local module README conventions.

A later Leader rework comment supersedes an earlier Executor interpretation.

If instructions conflict materially, do not guess silently. Preserve evidence and scope, document the conflict in the PR, and wait for Leader disposition.

---

## 3. Mandatory Pre-Work Checklist

Before editing, the Executor must identify:

- assigned Issue number;
- target branch;
- target PR title/body contract;
- exact in-scope modules/files;
- explicit out-of-scope topics;
- canonical source/toolchain versions;
- required verification levels;
- required learner/reviewer isolation.

At minimum read:

- root `AGENTS.md`;
- assigned Issue;
- linked roadmap/design document;
- `.editorial/GOVERNANCE.md`;
- `.editorial/REVIEW_POLICY.md`;
- `.editorial/AI_POLICY.md`;
- source/lab/version policies relevant to the task.

---

## 4. Evidence Rules

Use exactly:

- **VERIFIED**
- **PARTIALLY VERIFIED**
- **UNVERIFIED**

Keep these evidence classes separate:

1. source/version identity;
2. host test;
3. target compile/link;
4. static ELF/disassembly/register-contract check;
5. target flash/run;
6. live GDB/register observation;
7. physical waveform/measurement.

A successful build does not prove hardware behavior.

A static register configuration does not prove an interrupt fired.

A GDB command written in documentation is not a captured GDB result.

A predicted waveform is not a measured waveform.

When target evidence was not captured, use wording such as:

`EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED`

Never fabricate:

- terminal output;
- GDB output;
- register values;
- memory contents;
- sanitizer output;
- waveforms;
- benchmarks;
- timing numbers;
- source/version claims.

---

## 5. Scope and Assessment Rules

Executor work must stay inside the assigned Issue.

Do not pull later-module material forward just because it is convenient.

For challenge/fault/Gate work:

- learner-facing files must not reveal exact root causes;
- completed answers belong under reviewer-only structure;
- validators must test the learner artifact, not merely reference/base code;
- positive reviewer reference must pass;
- negative mutations must fail;
- static validators must not claim physical execution;
- Gate seeds must be unfamiliar variants, not exact replay of practiced faults.

---

# 6. Mandatory Executor Pull Request Handoff Contract

An Executor is **not finished** merely because code has been pushed.

Before telling the Leader that work is ready, the Executor MUST place a current, explicit handoff in its own PR.

Use either:

- the PR body; or
- a final PR comment headed exactly:

`## Executor Handoff Report`

The handoff must describe the **current remote revision**.

A one-line message such as “implemented, tests pass, waiting for review” is insufficient.

The purpose of the handoff is to give the Leader enough information to understand, reproduce, challenge, and review the Executor's work with confidence.

## Required Handoff Sections

### 6.1 Scope Delivered

State:

- Issue number;
- modules/tasks completed;
- explicit out-of-scope items not touched;
- any scope deviation and why.

### 6.2 What Changed

Summarize the actual implementation:

- important files/directories changed;
- architecture/algorithm/register/runtime decisions;
- labs/challenges/faults/Gates created or changed;
- validators/reviewer fixtures added;
- source/version/license updates;
- important behavior that changed from the prior revision.

Do not just list filenames. Explain the engineering effect.

### 6.3 Problems Encountered and How They Were Solved

For every meaningful problem encountered during the work, report:

```text
Problem / Symptom
→ Hypotheses considered
→ Evidence inspected
→ Root cause
→ Fix chosen
→ Regression / follow-up check
```

Include failed approaches when they materially affected the final design.

Do not hide implementation difficulty behind “completed successfully.”

If no meaningful problem was encountered, state that explicitly.

### 6.4 Verification Actually Performed

List **exact commands/tests actually run** and their actual results.

Separate:

- source/version checks;
- host/unit tests;
- target compile/link;
- ELF/map/nm/readelf/objdump checks;
- validator positive reference;
- validator negative mutations;
- target flash/run;
- live GDB;
- physical waveform/measurement.

Example format:

```text
Command:
make -C fundamentals/mcu/03-adc-dma-acquisition check

Result:
PASS on Ubuntu host toolchain arm-none-eabi-gcc X.Y.Z

Proves:
The target image compiles/links and static configuration checks pass.

Does NOT prove:
ADC conversions, DMA requests, interrupts, or waveform timing occurred on hardware.
```

### 6.5 Verification Boundary

Provide an explicit status table.

Example:

| Evidence | Status | Basis | Does not prove |
|---|---|---|---|
| Source pin | VERIFIED | exact tag/commit/blob comparison | target runtime |
| Target compile/link | VERIFIED | actual compiler execution | physical behavior |
| Live GDB | UNVERIFIED | no target attached | — |
| Waveform | UNVERIFIED | no scope capture | — |

Do not upgrade evidence because the expected behavior is obvious.

### 6.6 Sources / Toolchain / Environment

State:

- actual host OS/environment;
- actual compiler/binutils/GDB versions used;
- canonical toolchain baseline;
- exact upstream tags/commits/revisions;
- important source paths;
- licensing/source-origin constraints when relevant.

If the actual toolchain differs from canonical, say so explicitly.

### 6.7 Known Limitations / Residual Risks

Report:

- unresolved questions;
- hardware-only items not executed;
- portability assumptions;
- fragile validator assumptions;
- resource/timing assumptions;
- anything the Leader should inspect especially carefully.

If none are known, say:

> No known residual blocker remains **within the assigned scope**; hardware-only items listed above remain unverified.

Do not claim global correctness.

### 6.8 Git / PR State

State:

- branch;
- current remote HEAD SHA;
- PR number;
- `Closes #N` Issue link/contract;
- whether Leader commits were preserved;
- confirmation that the Executor did not merge.

### 6.9 Leader Review Request

End with:

- what is believed ready for review;
- which areas deserve highest Leader attention;
- any unresolved decision requiring Leader authority.

---

## 7. Rework Handoff Contract

When the Leader returns S2/S3 rework:

- continue on the same branch;
- update the same PR;
- preserve Leader commits;
- read the full latest Leader Issue comment/review;
- do not create a replacement PR unless explicitly ordered.

Before re-review, add/update a handoff headed:

`## Executor Rework Handoff — Round N`

It must state:

1. exact Leader rework comment/review addressed;
2. each requested item and how it was changed;
3. files/architecture affected;
4. problems encountered during rework and how they were solved;
5. exact verification rerun;
6. which prior Leader commits were preserved;
7. current remote HEAD SHA;
8. any item not fully resolved.

The report must describe the **latest PR state**, not repeat the original submission summary.

---

## 8. Leader Review Severity

- **S0 Cosmetic** — typo, formatting, naming, small link issue. Leader fixes directly.
- **S1 Minor** — local wording, source metadata, small code/evidence contract issue. Leader fixes directly.
- **S2 Major** — teaching order, assessment validity, unverifiable lab, wrong mechanism, weak validator, version/scope contract. Executor rework required.
- **S3 Critical** — fabricated evidence, false core mechanism, unsafe guidance, plagiarism/fake citation, fundamentally broken core implementation. Reject/re-author.

Review priority:

```text
Technical Correctness
> Observable Evidence
> Mental Model
> Teaching Sequence
> Debugging Transfer
> Source Quality
> Completeness
> Prose Polish
```

---

## 9. Merge Authority

Executor: **never merge**.

Leader: decides canonical inclusion and performs/authorizes the final merge after review.

A PR is not complete because CI/build/tests pass.

It is complete only after Leader review accepts:

- technical correctness;
- evidence integrity;
- assessment validity;
- source/version integrity;
- scope;
- teaching quality.

---

# 10. Copy-Ready Executor Handoff Template

```markdown
## Executor Handoff Report

### 1. Scope Delivered
- Issue:
- In scope completed:
- Explicitly not touched:

### 2. What Changed
- Architecture / implementation:
- Important files:
- Labs / challenges / faults / Gates:
- Validator / reviewer changes:
- Deviations from Issue:

### 3. Problems Encountered and How They Were Solved

#### Problem 1
- Symptom:
- Hypotheses:
- Evidence:
- Root cause:
- Fix:
- Regression:

#### Problem 2
- ...

### 4. Verification Actually Performed

#### Command / Test 1
- Command:
- Result:
- Proves:
- Does not prove:

#### Command / Test 2
- ...

### 5. Verification Boundary

| Evidence | Status | Basis | Does not prove |
|---|---|---|---|
| Source/version |  |  |  |
| Host tests |  |  |  |
| Target compile/link |  |  |  |
| Static ELF/disassembly |  |  |  |
| Target run |  |  |  |
| Live GDB/registers |  |  |  |
| Physical waveform |  |  |  |

### 6. Sources / Toolchain / Environment
- Host:
- Compiler:
- Binutils:
- GDB:
- Canonical baseline:
- Upstream pins:
- Important source paths:

### 7. Known Limitations / Residual Risks
- ...

### 8. Git / PR State
- Branch:
- Remote HEAD:
- PR:
- Closes:
- Leader commits preserved:
- Merge performed by Executor: NO

### 9. Leader Review Request
- Ready for review:
- Please inspect especially:
- Unresolved Leader decision:
```
