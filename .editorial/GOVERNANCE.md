# Editorial Governance

## Mission

`embed-system` is a living learning system for developing strong Embedded Systems Engineering capability, with a primary path through Embedded Linux, BSP, Linux drivers, SoC/platform engineering, bring-up, debugging, and performance.

The repository serves five roles at once:

1. tutorial;
2. lab book;
3. project portfolio;
4. debugging knowledge base;
5. career-alignment system.

## Operational Entry Point

Root `AGENTS.md` is mandatory before any agent work.

It defines the current operational workflow, role boundaries, evidence rules, and Executor PR handoff contract.

## Roles

### Leader / Editor-in-Chief / Technical Reviewer

The project Leader owns:

- curriculum architecture;
- task decomposition;
- GitHub Issue specifications;
- technical review;
- teaching review;
- source/version review;
- assessment-validity review;
- job-market alignment;
- S0/S1 direct fixes;
- S2/S3 rework disposition;
- canonical inclusion;
- final merge.

No Executor, researcher, draft writer, or lab designer has final editorial authority.

### Executor / Implementation Agent

The Executor is the operational role for an AI or contributor assigned to implement/research/draft/validate a Leader-authored Issue.

The Executor owns:

- reading `AGENTS.md`, the assigned Issue, and linked canonical documents before work;
- staying inside assigned scope;
- implementing the requested code/content/lab/research;
- running appropriate verification;
- preserving source/version/evidence integrity;
- creating or updating the assigned PR;
- maintaining the mandatory **Executor Handoff Report** in that PR;
- performing Leader-requested S2/S3 rework on the same PR.

The Executor must not:

- self-approve;
- self-promote to Leader;
- merge its own PR;
- claim canonical status;
- fabricate execution evidence;
- silently expand scope.

### Learner / Owner / Dispatcher

The repository owner:

- performs the learning tasks;
- runs real experiments;
- records genuine target evidence;
- dispatches short Leader-authored prompts that point Executors to full GitHub Issues.

The Learner/Dispatcher does not replace Leader technical review.

### Researcher / Draft Writer / Lab Designer

These are Executor specializations, not independent editorial authorities.

They may:

- collect sources;
- map a topic;
- draft text;
- propose diagrams;
- design labs;
- prepare code candidates.

They must follow the same Executor evidence and PR handoff rules.

## Canonical Workflow

```text
Leader Issue
→ Executor branch/work
→ Executor PR + Handoff Report
→ Leader Review
→ S0/S1 Leader direct fix OR S2/S3 Executor rework
→ Leader canonical decision / merge
```

Full task and rework specifications belong in GitHub Issues/review threads.

The short prompt given to an Executor should normally tell it to claim/read the Issue, execute it, update the assigned PR, and wait for Leader Review.

## Review Severity

- **S0 Cosmetic** — spelling, formatting, naming, link, minor style. Leader fixes directly.
- **S1 Minor** — local wording/source inconsistency/small code or evidence contract. Leader fixes directly.
- **S2 Major** — wrong teaching order, weak evidence, invalid assessment, unverifiable lab, mechanism/version/scope contract problem. Executor rework required.
- **S3 Critical** — false core technical claim, unsafe guidance, fabricated evidence, fake citation, plagiarism, fundamentally broken core implementation presented as valid. Reject/re-author.

## Merge Authority

The Executor never merges.

The Leader decides canonical inclusion and performs or authorizes the final merge after review.

A contribution is not ready merely because it reads well or passes a local build. It must pass:

- technical correctness;
- observable evidence integrity;
- mental-model quality;
- teaching coherence;
- assessment validity;
- source/version integrity;
- reproducibility;
- licensing/originality;
- scope discipline;
- career relevance.

## Living Book Principle

The repository may be restructured, rewritten, downgraded, or deleted as better evidence or higher-value learning paths emerge.
