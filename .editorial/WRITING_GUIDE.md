# Writing Guide

## Language

- Main explanation: Chinese.
- First occurrence of important terminology: Chinese + English term.
- APIs, symbols, registers, structure names, commands, and source paths: keep canonical English names.
- Gradually increase English technical output in later phases.

## Standard Chapter Shape

1. Why
2. Prerequisites
3. Mental Model
4. Theory
5. Official Source / Manual Walkthrough
6. Open-Source Implementation Walkthrough
7. Lab
8. Observation
9. Explain the Observation
10. Challenge
11. Fault Injection / Debug
12. Gate
13. Career Relevance
14. Further Reading
15. Source Ledger

Not every short note needs every section, but core chapters should follow this learning arc.

## Teaching Style

Prefer:

- concrete mental models;
- explicit assumptions;
- observable experiments;
- diagrams tied to explanations;
- real source paths and manual sections;
- trade-offs and failure cases.

Avoid:

- encyclopedia-style dumping;
- unexplained terminology;
- “obvious”, “simple”, or “just” where a learner can realistically get stuck;
- large copied code listings;
- claims with no evidence;
- fake measurements or fake logs.

## Depth Levels

- **L1 Know** — identify and define.
- **L2 Use** — use correctly in a normal task.
- **L3 Explain** — explain mechanisms and constraints.
- **L4 Debug / Design** — diagnose failure, design a solution, and explain trade-offs.

Core path topics eventually target L4.
