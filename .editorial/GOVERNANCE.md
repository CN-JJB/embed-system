# Editorial Governance

## Mission

`embed-system` is a living **resource-first engineering learning system** for developing strong Embedded Systems capability, especially in Embedded Linux, BSP, Linux drivers, SoC/platform engineering, bring-up, debugging and performance.

The repository is primarily responsible for:

1. a knowledge/dependency map;
2. a curated resource map;
3. source-reading guidance;
4. suggested experiments/projects;
5. debugging/evidence habits;
6. career-alignment and specialization choices.

It may also contain verified reference labs and projects, especially from earlier phases, but it is **not required to become a complete standalone textbook**.

## Operational entry point

Read root `AGENTS.md` before substantial AI/contributor work.

## Editorial principle

The optimization target is:

> reliable engineering capability gained per unit of learner time

Repository size, amount of AI prose, number of validators and number of Gates are not success metrics.

## Roles

### Leader / Editor / Technical Reviewer

The Leader owns:

- the overall learning architecture;
- source/resource quality;
- technical correctness;
- scope and sequencing;
- bounded corrections to stale material;
- canonical inclusion and merge;
- deciding when implementation-heavy authoring is actually justified.

### Research / Resource Agent

This is the default AI role.

It should:

- map knowledge prerequisites;
- locate primary sources and maintained expert material;
- verify version-sensitive claims;
- rank resources;
- identify exact source-reading targets;
- propose experiments and self-check questions;
- keep optional depth out of the critical path.

It should not create a large bespoke tutorial or assessment framework unless explicitly requested.

### Implementation Agent

Implementation is a special case, used for:

- a small reference experiment;
- a reproducibility helper;
- a bounded existing fix;
- an explicitly requested project/lab.

Implementation agents must report actual evidence honestly and must not merge unless assigned Leader authority.

### Learner

The learner owns the most important work:

- reading;
- coding;
- building;
- debugging;
- measuring;
- source navigation;
- recording real evidence;
- transferring knowledge to unfamiliar cases.

The repository should preserve productive struggle rather than pre-solving every exercise.

## Canonical workflow

For research/resource work:

```text
research question / roadmap gap
→ source review
→ concise roadmap/resource change
→ technical review
→ merge
```

For implementation-heavy work:

```text
explicit implementation task
→ implementation branch/PR
→ evidence report
→ technical review
→ merge/rework
```

A large hidden assessment system is never required merely because a topic exists.

## Review severity

- **S0 Cosmetic** — typo, formatting, minor link problem.
- **S1 Minor** — small source metadata or local technical clarification.
- **S2 Major** — wrong mechanism, poor source choice, wrong learning dependency, misleading evidence, unnecessary large scope, or stale version-sensitive guidance.
- **S3 Critical** — fabricated evidence, fake source/citation, unsafe instruction, plagiarism, fundamentally false technical claim, or assessment answer leakage presented as valid.

Review priority:

```text
Technical Correctness
> Source Authority
> Mental Model / Learning Dependency
> Evidence Honesty
> Practical Transfer Value
> Scope Efficiency
> Prose Polish
```

## Evidence

When evidence status is material, use only:

- **VERIFIED**
- **PARTIALLY VERIFIED**
- **UNVERIFIED**

Do not collapse source inspection, emulated runtime and physical hardware into one claim.

## Existing material

Phase 1–3 contain significant historical implementation-heavy work. Keep useful verified material as optional reference exemplars.

Do not use the existence of those assets as precedent that future phases need equivalent scaffolding.

The project may rewrite, downgrade, archive or delete material when a better learning path emerges.
