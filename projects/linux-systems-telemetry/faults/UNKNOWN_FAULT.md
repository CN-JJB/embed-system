# AI-Free Unknown Project Fault

## Symptom
During system shutdown, the telemetry service occasionally stalls indefinitely rather than terminating cleanly upon reaching EOF or receiving a termination signal. Process inspection reveals that the main thread is waiting on `pthread_join` for the ingestion worker thread, but the worker thread never exits.

## Required Diagnostic Protocol
To pass this assessment, you must submit a structured postmortem following the canonical diagnostic chain:

```
Symptom
→ Own Description
→ 3–5 Hypotheses
→ First Evidence + Why
→ Observation
→ Narrow Scope
→ Root Cause
→ Fix
→ Regression
```

A patch submitted without supporting diagnostic evidence does NOT pass.

## Bounded Reproduction Harness
A reproduction fixture is provided in `faults/unknown/repro.c`. It includes a bounded watchdog timer (3 seconds) to prevent the reproduction from hanging indefinitely:

```bash
make build/unknown_repro
./build/unknown_repro
```

When run against the broken implementation, the watchdog terminates the process with an error code, confirming reproduction of the hang without stalling CI or test runners.

## Regression Requirements
Your fix must be accompanied by a regression test proving the complete shutdown lifecycle:
1. When shutdown or EOF is triggered while the pipeline is idle, all active worker threads terminate promptly without stalls.
2. Thread join in the main/coordinator thread completes successfully without timeouts.
3. All synchronization primitives and allocated pipeline resources are destroyed cleanly.
4. The regression suite must run cleanly across repeated cycles (e.g. 100 iterations) without intermittent deadlocks or timing failures.

## Safety & Cleanup
Do not leave stray background processes or indefinite sleeps. Always clean up temporary build artifacts:
```bash
rm -f build/unknown_repro
```
