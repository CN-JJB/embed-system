# Review Policy

Root `AGENTS.md` defines role authority and the mandatory Executor PR handoff contract.

## Review Priority

Review in this order:

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

## Review Axes

### 1. Technical correctness
Are mechanisms, APIs, registers, code, diagrams, and source interpretations correct?

### 2. Evidence quality
Are claims backed by the right evidence class, and are execution boundaries honest?

### 3. Mental model quality
Will the contribution teach a durable, transferable mechanism rather than an accidental implementation detail?

### 4. Teaching order
Do prerequisites exist before advanced concepts are introduced?

### 5. Assessment validity
Do challenges/faults/Gates test the intended competency without leaking answers or replaying exact practiced seeds?

### 6. Reproducibility
Can the stated build/test/validator path be rerun in the documented environment?

### 7. Debug value
Does the learner practice symptom → hypotheses → evidence → root cause → fix → regression?

### 8. Version integrity
Are kernel/toolchain/RTOS/SoC versions explicit, pinned, and consistent with what was actually executed?

### 9. Resource/source quality
Are specifications, upstream sources, official documentation, and teaching resources appropriately selected and traced?

### 10. Licensing/originality
Are quotations, figures, source code, vendor templates, and generated material handled appropriately?

### 11. Scope discipline
Does the PR implement the assigned Issue without silently pulling later-module curriculum forward?

## Review Severity

### S0 — Cosmetic
Examples:
- typo;
- formatting;
- naming;
- broken internal link.

Leader fixes directly.

### S1 — Minor
Examples:
- local wording ambiguity;
- small source metadata issue;
- narrow code-contract issue;
- verification-status wording inconsistency.

Leader fixes directly when practical.

### S2 — Major
Examples:
- wrong teaching sequence;
- assessment can false-pass;
- wrong mental model;
- source/version mismatch;
- invalid lab evidence;
- scope violation;
- missing major verification contract.

Leader writes the full rework specification in the related Issue/review thread. Executor updates the same PR.

### S3 — Critical
Examples:
- false core technical mechanism;
- fabricated logs/GDB/register/waveform/benchmark evidence;
- fake citation;
- plagiarism;
- unsafe instructions;
- fundamentally broken core code presented as verified.

Reject/re-author.

## Executor Handoff Review

Before deep technical review, the Leader should verify that the current PR contains the mandatory `## Executor Handoff Report` or current rework handoff required by `AGENTS.md`.

The handoff is part of the review evidence, not administrative decoration.

The Leader should be able to determine from the PR:

- what the Executor changed;
- why major decisions were made;
- what problems were encountered;
- how those problems were diagnosed and solved;
- what exact verification was run;
- what remains unverified;
- which risks deserve special review attention;
- which remote revision is being handed off.

A stale handoff describing an earlier PR revision is insufficient.

## S2/S3 Rework Output

A major rework specification should state:

1. problem;
2. why it matters;
3. evidence;
4. exact revision required;
5. acceptance test;
6. preservation requirements for Leader commits;
7. scope/no-merge constraints.

The full rework specification belongs in the GitHub Issue/review thread. The user-facing Executor prompt should remain short and point to that source of truth.
