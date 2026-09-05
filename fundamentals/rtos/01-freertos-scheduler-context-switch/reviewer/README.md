# P2-M04 Reviewer Materials & Assessment Solutions

> **NOTICE: REVIEWER-SIDE ISOLATION**  
> The documents and reference fixtures in this directory are reserved for evaluators and automated test harnesses.  
> Under the Phase 2 AI-Free policy, learners must not reference these files during challenge or gate assessments.

## Contents
- `challenge-reference/`: Authoritative reference implementation bundle (`scheduler_app.c`, `scheduler_app.h`, `FreeRTOSConfig.h`) for P2-M04 Challenge.
- `mutations/`: 10 deterministic negative mutation bundles evaluating `challenge/validate.sh`.
- `challenge_solution.md`: Technical analysis, timing guarantees, and reference implementation breakdown.
- `gate_solution.md`: Comprehensive diagnosis, Cortex-M NVIC register evidence, and minimal fix for the Module Gate.
- `fault_analysis.md`: Hypothesis trees, disassembly/GDB inspection commands, and minimal fixes for learner faults `f1`–`f5`.
- `hints.md`: Progressive pedagogical hints for Socratic mentoring.
- `test_m04_validator_mutations.sh`: Automated test runner for validator mutation regression.
- `verify_gate_regression.sh`: Automated binary verification for the seeded Gate fixture.
