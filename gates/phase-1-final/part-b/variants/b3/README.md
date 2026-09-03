# Variant B3 — Diagnostic Exercise

## Symptom
When executing the multi-threaded metrics harness `./repro`, the test reports data race anomalies or invariant violations where minimum values exceed maximum values during concurrent updates.

## Reproduction
```bash
make repro
./repro
```

The harness is bounded by a 3-second safety watchdog timer.

## Assignment
1. Formulate 3–5 hypotheses explaining why concurrent metric updates violate multi-field consistency.
2. Select and run targeted diagnostic experiments (e.g. ThreadSanitizer or invariant auditing) to locate the synchronization defect.
3. Apply a minimal, principled fix and submit your findings in the 8-step diagnostic report format.
