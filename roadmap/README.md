# Roadmap Index — Current Canonical Direction

This directory contains both historical detailed blueprints and the current resource-first learning map.

## Current authority

For **what to learn next and how to use resources**, start with:

- [`MASTER_LEARNING_MAP.md`](MASTER_LEARNING_MAP.md)
- [`../resources/CANONICAL_RESOURCES.md`](../resources/CANONICAL_RESOURCES.md)

The older Phase 1–3 roadmaps remain useful because they contain detailed dependency analysis, source pins and proven exercises. They are no longer a commitment to keep generating the same amount of tutorial/assessment infrastructure for every future phase.

## Status

| Phase | Theme | Current status | Default authoring model |
|---|---|---|---|
| Phase 0 | baseline / tooling / evidence habits | canonical foundation | concise checklist |
| Phase 1 | System C + Linux userspace | detailed canonical material exists | use existing material + resources |
| Phase 2 | STM32 + FreeRTOS | detailed canonical material exists | use existing material + vendor/upstream docs |
| Phase 3 | Embedded Linux boot chain | M01–M08 canonical reference material exists | use existing material + Bootlin/upstream resources |
| Phase 3 Final Gate | former heavy AI-Free assessment plan | **retired as mandatory authoring** | learner self-check/project instead |
| Phase 4 | Linux drivers / device model | resource roadmap | learner-built drivers |
| Phase 5 | BSP / bootloader / build systems | resource roadmap | learner-built BSP integration |
| Phase 6 | bring-up / debugging / performance / real-time | resource roadmap | evidence-driven field practice |

## Important interpretation

“Canonical” now means the repository has a trusted learning direction and resource set. It does **not** mean every module must ship a custom validator, hidden seed, solved fault, or fully authored lesson.

Existing verified Phase 1–3 assets are preserved as optional exemplars. New phases deliberately become leaner and put more responsibility on the learner to read, implement, debug and measure.
