# AI Use Policy

AI is a **navigator, research accelerator and reviewer**. It is not a substitute for reading primary sources, writing code, debugging, measurement or engineering judgment.

## Default mode: AI-guided self-directed learning

For most roadmap work, AI should:

- map prerequisites and learning order;
- find authoritative resources;
- point to exact source files/functions/sections;
- summarize only after sources are identified;
- explain confusing concepts in bounded original wording;
- suggest experiments without fully solving them;
- ask diagnostic questions;
- review learner reasoning/code after an attempt;
- identify stale or conflicting claims;
- recommend what can safely be deferred.

The learner should do the implementation and debugging whenever that effort is itself the learning objective.

## AI-Free moments

Useful, but not mandatory as a large formal Gate system.

Examples:

- reconstruct a small mechanism from blank files;
- first attempt at an unfamiliar debugging problem;
- explain a source path without AI assistance;
- perform a project milestone before requesting review.

These can be simple self-checks; they do not require hidden-seed infrastructure.

## AI-Hint

AI may:

- ask for hypotheses;
- point to a manual/source location;
- recommend evidence to collect;
- identify a missing distinction;
- provide progressively stronger hints.

Prefer this mode when the learner is actively debugging.

## AI-Assisted review

After a learner attempt, AI may:

- review code and design;
- compare behavior with primary sources;
- suggest tests;
- explain compiler/kernel/tool output;
- identify likely bugs and missing evidence;
- propose local refactors;
- compare multiple implementation approaches.

## AI-generated implementation

Substantial generated code is appropriate when implementation is not the learning objective or when the user explicitly requests it.

When the purpose is to learn a mechanism, prefer:

```text
resource + constraints + questions + suggested experiment
```

over handing over a complete final implementation.

Small reference snippets are acceptable when they clarify an API or mechanism, but they should not silently replace the learner's project.

## Research rules

AI must not:

- fabricate sources or citations;
- invent version numbers/commits;
- fabricate execution, debugger or hardware evidence;
- claim a command was run when it was not;
- turn expected behavior into VERIFIED behavior;
- silently resolve conflicting primary sources by guessing;
- use an old tutorial as authority over current upstream documentation/source;
- generate huge amounts of curriculum merely to appear comprehensive.

Unknowns should remain explicit.

## Source authority

For version-sensitive claims:

```text
official spec/vendor manual/upstream docs
> exact upstream source
> maintained expert course
> classic book
> secondary explanation
> AI synthesis
```

A classic book can still be the best mental-model resource even when it is not the current implementation authority.

## Evidence language

When needed, use exactly:

- **VERIFIED**
- **PARTIALLY VERIFIED**
- **UNVERIFIED**

Separate source verification, static checks, emulation/runtime and physical hardware evidence.

## The learner remains responsible for

- deciding what they actually understand;
- reproducing experiments;
- capturing real target evidence;
- checking electrical/hardware limits;
- debugging their implementation;
- maintaining personal notes;
- asking for review when stuck or after a meaningful attempt.
