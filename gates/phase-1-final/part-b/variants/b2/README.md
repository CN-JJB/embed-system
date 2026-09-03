# Variant B2 — Diagnostic Exercise

## Symptom
When executing the logging harness `./repro`, the test reports descriptor table growth and resource retention across rotation cycles.

## Reproduction
```bash
make repro
./repro
```

The harness is bounded by a 3-second safety watchdog timer.

## Assignment
1. Formulate 3–5 hypotheses explaining why active file descriptors accumulate.
2. Select and run targeted diagnostic experiments (e.g. inspecting `/proc/self/fd`) to identify the unclosed descriptor.
3. Apply a minimal, principled fix and submit your findings in the 8-step diagnostic report format.
