# Integrated Fault Campaign: STM32 FreeRTOS Acquisition Node

This directory contains three diagnostic-neutral fault scenarios designed to test systemic debugging, hypothesis formation, and root-cause isolation in an integrated embedded RTOS environment.

## Fault Scenarios Overview

| Scenario | Subsystem | Manifested Symptom |
|---|---|---|
| [`f1_missing_telemetry_sequence`](./f1_missing_telemetry_sequence/) | Telemetry / DMA / Pipeline | Telemetry sequence gaps observed on serial console with zero reported drops |
| [`f2_frozen_sensor_no_reboot`](./f2_frozen_sensor_no_reboot/) | Supervision / Watchdog | System hangs indefinitely without watchdog reset when sensor input ceases |
| [`f3_sporadic_latency_jitter`](./f3_sporadic_latency_jitter/) | Task Pipeline / Timing | Severe periodic acquisition latency jitter and missed sample deadlines |

---

## Pedagogical Workflow

For each scenario:
1. **Observe the Symptom**: Read the manifested symptom description and examine serial logs, logic analyzer traces, or register state.
2. **Formulate Hypotheses**: Propose 3 to 5 distinct candidate hypotheses explaining how the observable symptoms could arise in the system architecture.
3. **Design Discriminative Experiments**: Identify what observable evidence, instrumentation GPIO markers, or debugger inspections distinguish between hypotheses.
4. **Isolate Root Cause**: Inspect relevant architectural components, verify invariants, and identify the root cause without speculative trial-and-error.
5. **Implement and Validate Fix**: Apply a minimal surgical correction and confirm that both unit verification and `scripts/verify_project.sh` pass.

