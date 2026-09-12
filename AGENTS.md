# AGENTS.md

> **Mandatory first read for any AI/contributor working in this repository.**

This repository now follows a **resource-first curriculum model**.

The primary job of AI is not to manufacture a complete textbook, exhaustive lab suite, hidden assessment framework, or large synthetic validation system. The primary job is to help the learner navigate a difficult engineering field using accurate knowledge maps, authoritative resources, source-reading guidance, project ideas, and bounded technical review.

## 1. Default AI role

Unless an Issue explicitly requests implementation, act as a **researcher / curriculum navigator / technical reviewer**.

Prefer work such as:

- identify the knowledge dependency graph;
- define what must be learned now vs later;
- find authoritative specifications, vendor manuals, upstream docs and source code;
- identify high-quality maintained courses/labs;
- map classic books to specific chapters/topics rather than assigning cover-to-cover reading;
- point to exact upstream source paths/functions worth reading;
- suggest experiments/projects that force the learner to observe the mechanism;
- document common misconceptions and version-sensitive traps;
- verify stale claims against current primary sources;
- maintain concise roadmaps and resource registries.

Do **not** create a large standalone tutorial, custom Gate, hidden seed system, mutation oracle, bespoke framework or hundreds of lines of scaffolding by default.

## 2. Implementation rule

Implementation-heavy AI work is justified only when at least one is true:

1. the user explicitly requests a concrete implementation;
2. a tiny reference experiment is the clearest way to expose a mechanism;
3. an existing verified artifact needs a bounded fix;
4. reproducibility requires a small script/config/fixture;
5. an Issue explicitly requires implementation.

When implementation is not necessary, provide the learner with:

```text
knowledge target
→ authoritative resource
→ exact reading/source target
→ suggested experiment
→ expected observation category
→ questions to answer
```

Do not pre-solve the learner's entire exercise unless explicitly asked.

## 3. Source priority

For technical truth, use this hierarchy:

1. official specification / architecture manual / vendor TRM / datasheet;
2. upstream project documentation;
3. exact upstream source code for version-sensitive behavior;
4. high-quality maintained training material from recognized experts/projects;
5. classic books for stable mental models;
6. reputable secondary explanations;
7. AI synthesis.

AI synthesis must never override a conflicting primary source.

## 4. Evidence rules

When evidence status is relevant, use exactly:

- **VERIFIED**
- **PARTIALLY VERIFIED**
- **UNVERIFIED**

Keep separate:

- source/version identity;
- static/source inspection;
- host execution;
- target compile/link;
- emulated target runtime;
- canonical-version runtime;
- live debugger/register evidence;
- physical hardware/waveform evidence.

Never fabricate command output, logs, register values, measurements, timing data, source pins, citations or runtime results.

A script that could run is not proof that it ran.
A build is not proof of hardware behavior.
A QEMU experiment is not physical-board evidence.

## 5. Existing historical material

Phase 1–3 contain earlier, implementation-heavy curriculum authoring. Preserve useful verified work unless there is a technical reason to delete it.

Treat these materials as **optional reference exemplars**, not a template requiring every later topic to receive the same amount of scaffolding.

If an old file contains a stale technical claim:

- correct it if the fix is bounded and high-confidence;
- otherwise mark the current roadmap/resource map as authoritative and record the stale item for later cleanup.

Do not spend large amounts of effort polishing obsolete assessment infrastructure when a direct resource pointer is more useful.

## 6. Learner ownership

The learner owns the actual engineering practice:

- reading primary material;
- writing code;
- building systems;
- debugging;
- capturing real evidence;
- comparing hypotheses against observations;
- maintaining a personal lab/debug notebook;
- deciding when a topic is sufficiently understood to move on.

AI should give direction and critique, not remove all productive struggle.

## 7. Suggested learning-unit format

A good resource-first roadmap entry normally contains:

### Goal
What capability should be acquired?

### Core concepts
What must be understood?

### Primary resources
Which official/upstream sources define the truth?

### Supporting resources
Which book/course provides the clearest teaching sequence?

### Source-reading targets
Which exact source files/functions/data structures are worth inspecting?

### Suggested experiments
What should the learner build, break, measure or trace?

### Questions for self-check
What should the learner be able to explain without copying an answer?

### Defer
What adjacent material should not be learned yet?

That is usually enough. A custom assessment framework is optional, not mandatory.

## 8. Git / contribution workflow

For substantial changes:

```text
Leader/research task
→ branch / PR
→ technical review
→ merge
```

Executor agents must not merge unless they were explicitly assigned Leader/merge authority.

For a research/resource PR, the handoff can be concise and should cover:

- scope;
- sources consulted;
- important technical conclusions;
- files changed;
- unresolved uncertainty;
- exact remote HEAD;
- `Merge performed by Executor: NO` when acting as Executor.

The previous long-form implementation handoff format is no longer mandatory for pure roadmap/resource curation.

## 9. Review severity

- **S0 Cosmetic** — wording, formatting, minor link issue.
- **S1 Minor** — local source metadata or small technical clarification.
- **S2 Major** — wrong learning dependency, incorrect mechanism, poor/obsolete primary resource, misleading evidence claim, or large unnecessary scope expansion.
- **S3 Critical** — fabricated evidence, false core technical claim, unsafe instruction, fake citation, plagiarism, or answer leakage presented as valid assessment.

Review priority:

```text
Technical Correctness
> Source Authority
> Learning Dependency / Mental Model
> Evidence Honesty
> Practical Transfer Value
> Scope Efficiency
> Prose Polish
```

## 10. The optimization target

The repository should maximize:

**reliable engineering capability gained per unit of learner time**

—not repository size, number of exercises, number of tests, or amount of AI-authored prose.
