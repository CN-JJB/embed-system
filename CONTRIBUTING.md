# Contributing to embed-system

This repository uses a role-separated editorial workflow. Tutorial text, code, labs, assessments, and research are not automatically publishable because they build or pass local tests.

## Mandatory First Read

Before any AI agent or contributor starts work, read:

1. **`AGENTS.md`** — mandatory Leader / Executor workflow and PR handoff contract.
2. the assigned GitHub Issue;
3. every canonical design/roadmap document linked by that Issue;
4. the relevant `.editorial/` policies.

The root `AGENTS.md` is the operational entrypoint for all agent work.

## Canonical Workflow

```text
Leader creates full GitHub Issue
→ Executor implements/researches on assigned branch
→ Executor opens/updates its PR
→ Executor writes a complete Handoff Report in that PR
→ Leader reviews
→ S0/S1: Leader may fix directly
→ S2/S3: Executor reworks the same PR
→ Leader decides canonical inclusion and merge
```

The Executor **never merges its own PR**.

## Executor Completion Requirement

Before reporting work as complete, the Executor must update its own PR with the mandatory **Executor Handoff Report** defined in `AGENTS.md`.

The report must explain, at minimum:

- what was implemented;
- what changed and why;
- meaningful problems encountered;
- hypotheses/evidence/root cause/fix/regression for those problems;
- exact commands/tests actually run and actual results;
- VERIFIED / PARTIALLY VERIFIED / UNVERIFIED boundaries;
- toolchain/source/version identity;
- known limitations and residual risks;
- branch, remote HEAD, PR, Issue closing contract;
- what the Leader should inspect especially carefully.

“Implemented, tests pass, waiting for review” is not a sufficient handoff.

After Leader rework, the Executor must update the same PR with a current rework handoff describing the latest revision.

## Editorial Policies

See:

- `.editorial/GOVERNANCE.md`
- `.editorial/SOURCE_POLICY.md`
- `.editorial/RESOURCE_POLICY.md`
- `.editorial/WRITING_GUIDE.md`
- `.editorial/LAB_STANDARD.md`
- `.editorial/IMAGE_POLICY.md`
- `.editorial/REVIEW_POLICY.md`
- `.editorial/AI_POLICY.md`
- `.editorial/VERSION_POLICY.md`

## Core Principle

A convincing explanation is not enough.

Content should be:

- correct;
- sourced;
- teachable;
- reproducible;
- observable;
- debuggable;
- version-aware;
- assessment-valid;
- useful to the target engineering path.
