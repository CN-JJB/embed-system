# Unknown Fault Bounded Reproduction Fixture

## Objective
Reproduce the shutdown hang symptom safely using the bounded reproduction harness.

## Reproduction Command
```bash
make build/unknown_repro
./build/unknown_repro
```

## Expected Observation
The reproduction harness runs a simulated ingestion pipeline and initiates service shutdown.

Under the fault condition, the service fails to terminate within normal limits. After 3 seconds of shutdown stall, the safety watchdog terminates the process to prevent an indefinite hang:
```
=== Unknown Fault Reproduction Harness ===
[main] Ingestion worker started...
[main] Initiating service shutdown...
[main] Waiting for worker thread to join...

>>> TIMEOUT: Telemetry service shutdown hung! Process failed to exit within 3s. <<<
```
Exit code: `2`.

## Diagnostic Strategy
1. Formulate 3–5 hypotheses based on the observed symptom before running diagnostic tools.
2. Inspect thread states and backtraces (using GDB, core dumps, or code tracing) to determine where execution is stalled.
3. Complete the 8-step postmortem protocol:
   `Symptom → Own Description → 3–5 Hypotheses → First Evidence + Why → Observation → Narrow Scope → Root Cause → Fix → Regression`.
