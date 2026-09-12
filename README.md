# embed-system

A resource-first learning map for becoming a strong Embedded Systems Engineer, with emphasis on:

- Embedded Linux
- Linux kernel drivers
- BSP / boot flow / build systems
- SoC and platform engineering
- MCU / RTOS foundations
- bring-up and debugging
- performance and real-time behavior
- hardware-software co-design

> **Status:** Phase 1–3 knowledge maps and verified reference work are canonical. The repository is now in **resource-first mode**: future AI work prioritizes authoritative resources, learning order, source-reading targets, suggested experiments, and bounded technical corrections rather than generating a large standalone textbook or exhaustive assessment framework.

## What this repository is

This repository is primarily a **navigation and engineering-practice system**. It tells the learner:

1. what to learn;
2. in what order;
3. which primary sources and high-quality courses/books to use;
4. which upstream code is worth reading;
5. what experiments or projects are worth attempting;
6. what evidence would demonstrate real understanding;
7. which topics can safely be deferred.

Existing verified labs, scripts, gates and projects are retained as **optional reference exemplars**. They are not a requirement that every future topic receive an AI-authored tutorial, hidden-seed gate, mutation oracle or custom validator.

The learner is expected to do the actual learning, implementation, debugging and experimentation from the cited resources.

## Start here

- [Master Learning Map](roadmap/MASTER_LEARNING_MAP.md)
- [Roadmap Status and Phase Index](roadmap/README.md)
- [Canonical Resources](resources/CANONICAL_RESOURCES.md)
- [Resource Policy](.editorial/RESOURCE_POLICY.md)
- [Governance](.editorial/GOVERNANCE.md)

## Current phase map

```text
Phase 0  Baseline / environment / evidence habits
   ↓
Phase 1  System C + Linux userspace foundations
   ↓
Phase 2  MCU + STM32 + FreeRTOS mechanisms
   ↓
Phase 3  Embedded Linux boot chain and appliance fundamentals
   ↓
Phase 4  Linux kernel driver model and subsystem drivers
   ↓
Phase 5  BSP / bootloader / build-system / board integration
   ↓
Phase 6  Bring-up / debugging / tracing / performance / real-time
   ↓
Optional specialization: networking, graphics, security, hardware-software co-design
```

Phase 1–3 contain substantial historical authoring and verified examples. Phase 4–6 are deliberately **leaner resource maps**: they point to current upstream documentation and proven training material and suggest self-directed projects rather than pre-solving the work.

## Resource philosophy

For version-sensitive engineering, prefer this order:

```text
official specification / vendor TRM / upstream documentation
→ upstream source code
→ high-quality maintained course/lab
→ classic book for durable mental model
→ learner-built experiment
```

Blogs and AI explanations are supporting material, not the final authority for kernel, architecture, peripheral or build-system behavior.

## Existing verified work

Previously authored Phase 1–3 material is not discarded merely because the authoring strategy changed. Work that captured real source/version evidence or real runtime behavior remains useful as a reference. Unverified or synthetic material must remain explicitly labelled and must not be promoted to runtime or hardware evidence.

## Editorial system

AI is now primarily a **researcher, navigator and technical reviewer**. It should:

- map knowledge and dependencies;
- find authoritative resources;
- verify version-sensitive claims against primary sources;
- recommend source-reading targets;
- suggest experiments and projects without pre-solving them;
- identify misconceptions and stale material;
- keep the learning path bounded and career-relevant.

AI should **not** create a large new tutorial or custom assessment framework by default. Implementation-heavy authoring requires an explicit reason and should be kept small.

See [`AGENTS.md`](AGENTS.md) and [`.editorial/`](.editorial/) for the current rules.
