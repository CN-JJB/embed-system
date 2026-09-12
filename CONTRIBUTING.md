# Contributing to embed-system

This repository follows a **resource-first editorial workflow**.

Most contributions should improve one of these:

- knowledge/dependency maps;
- authoritative resource selection;
- source-reading targets;
- learning sequence;
- experiment/project suggestions;
- bounded corrections to stale technical claims;
- concise notes from verified real experiments.

Large tutorial packages, custom Gates, hidden-seed systems, mutation frameworks and bespoke validators are **not required by default**.

## Mandatory first read

Before substantial work, read:

1. `AGENTS.md`;
2. the relevant roadmap/resource file;
3. `.editorial/GOVERNANCE.md`;
4. `.editorial/RESOURCE_POLICY.md`;
5. `.editorial/REVIEW_POLICY.md`;
6. `.editorial/AI_POLICY.md`.

## Preferred contribution workflow

For resource/research changes:

```text
identify learning gap
→ check primary sources/current upstream docs
→ make a concise roadmap/resource change
→ open PR
→ technical review
→ merge
```

For explicit implementation work:

```text
bounded implementation task
→ branch / PR
→ report what was actually built/run
→ technical review
→ merge/rework
```

An Executor must not merge unless explicitly assigned Leader/merge authority.

## What a good resource PR contains

- clear scope;
- ranked sources rather than a link dump;
- explanation of what each resource is for;
- exact source-reading targets when useful;
- learning-order rationale;
- suggested experiment/project direction;
- known uncertainty or version sensitivity;
- no fabricated evidence.

A concise PR is preferable to a large amount of generated prose.

## Evidence

When evidence status matters, use only:

- `VERIFIED`
- `PARTIALLY VERIFIED`
- `UNVERIFIED`

Do not confuse source inspection, target build, emulated runtime and physical hardware evidence.

## Editorial policies

See `.editorial/` for source, resource, writing, lab, image, review, AI and version policies.

## Core principle

The repository should maximize **reliable engineering capability per unit of learner time**.

A good contribution helps the learner find the right truth source, understand the dependency, do the right experiment, and avoid a known misconception. It does not need to pre-build the entire learning experience.
