# Roadmap Index — Current Canonical Direction

This directory contains both historical detailed blueprints and the current resource-first learning maps.

## If you are a learner

Do **not** use this directory as the first entry point.

Start with:

1. [`../START_HERE.md`](../START_HERE.md) — linear route and next action.
2. [`../resources/TOPIC_RESOURCE_INDEX.md`](../resources/TOPIC_RESOURCE_INDEX.md) — exact resource slice for each numbered unit.
3. [`MASTER_LEARNING_MAP.md`](MASTER_LEARNING_MAP.md) — broad dependency/competency context.
4. The phase document below when you want deeper scope/history.

This separation is deliberate:

```text
START_HERE = where do I go next?
TOPIC_RESOURCE_INDEX = exactly what do I read/do for this topic?
MASTER_LEARNING_MAP = how does this topic fit the whole engineer skill tree?
phase-N roadmap = deeper phase design/context
```

## Phase index

| Phase | Theme | Main phase document | Current status | Learner usage |
|---|---|---|---|---|
| Phase 0 | baseline / tooling / evidence habits | [`../gates/phase-0-baseline/README.md`](../gates/phase-0-baseline/README.md) | canonical foundation | diagnostic + targeted remediation |
| Phase 1 | System C + Linux userspace | [`phase-1-foundations.md`](phase-1-foundations.md) | detailed canonical material exists | follow P1 units in `START_HERE`; existing modules are reference/orientation |
| Phase 2 | STM32 + FreeRTOS | [`phase-2-stm32-freertos.md`](phase-2-stm32-freertos.md) | detailed canonical material exists | follow P2 units; vendor/upstream docs remain authority |
| Phase 3 | Embedded Linux boot chain | [`phase-3-embedded-linux.md`](phase-3-embedded-linux.md) | M01–M08 canonical reference material exists | follow P3 units; attempt integration before reading solved M08 project |
| Phase 3 Final Gate | former heavy AI-Free assessment plan | — | **retired as mandatory authoring** | learner self-check/project instead |
| Phase 4 | Linux drivers / device model | [`phase-4-linux-drivers-bsp.md`](phase-4-linux-drivers-bsp.md) | resource roadmap | follow P4.1–P4.11 in the topic index; learner builds drivers |
| Phase 5 | BSP / bootloader / build systems | [`phase-5-bsp-build-boot.md`](phase-5-bsp-build-boot.md) | resource roadmap | follow P5.1–P5.8; learner builds BSP integration |
| Phase 6 | bring-up / debugging / performance / real-time | [`phase-6-debug-performance.md`](phase-6-debug-performance.md) | resource roadmap | follow P6.1–P6.10; evidence-driven field practice |

## Current authority

For **learning order**, `START_HERE.md` is authoritative.

For **topic-to-resource mapping**, `resources/TOPIC_RESOURCE_INDEX.md` is authoritative.

For **broad scope/dependencies**, `MASTER_LEARNING_MAP.md` is authoritative.

The older Phase 1–3 roadmaps remain useful because they contain detailed dependency analysis, source pins and proven exercises. They are no longer a commitment to keep generating the same amount of tutorial/assessment infrastructure for every future phase.

## Important interpretation

“Canonical” means the repository has a trusted learning direction and resource set. It does **not** mean every module must ship a custom validator, hidden seed, solved fault, or fully authored lesson.

Existing verified Phase 1–3 assets are preserved as optional exemplars. New phases deliberately become leaner and put more responsibility on the learner to read, implement, debug and measure.
