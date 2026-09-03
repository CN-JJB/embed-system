# Variant B1 — Diagnostic Exercise

## Symptom
When executing the event processing harness `./repro` under AddressSanitizer, the application aborts during the summary query stage with a memory safety violation.

## Reproduction
```bash
make repro
./repro
```

The harness is bounded by a 3-second safety watchdog timer to prevent indefinite hangs.

## Assignment
1. Formulate 3–5 hypotheses explaining why the query stage encounters an invalid memory access.
2. Select and run targeted diagnostic experiments to isolate the broken lifetime or ownership contract.
3. Apply a minimal, principled fix and submit your findings in the 8-step diagnostic report format.
