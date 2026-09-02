# M09 Gate — Concurrency & Invariant Audit

**AI-Free Gate: Seeded Concurrency Fault Diagnosis and Repair**

## Objective
Diagnose and repair three runnable concurrency failure domains in `gate/gate_seeded.c`:
1. **Domain 1: Race / Unsynchronized Access** (`./build/gate_seeded race`)
2. **Domain 2: Multi-Field Invariant Violation** (`./build/gate_seeded invariant`)
3. **Domain 3: Condition-Variable Predicate / Close Bug** (`./build/gate_seeded condvar`)

## Execution Instructions
Build the gate fixture:
```bash
make gate-seeded
```

Run each station to reproduce the failure symptoms:
```bash
./build/gate_seeded race
./build/gate_seeded invariant
./build/gate_seeded condvar
```

## Required Submission Structure
For each domain, submit a complete diagnostic postmortem:
1. **Symptom**: Observed behavior upon running the seeded station.
2. **Own Description**: Explanation in your own words of what failed.
3. **3–5 Hypotheses**: Plausible explanations before instrumenting or running tools.
4. **First Evidence + Why**: Exact tool command or inspection point chosen to disambiguate hypotheses, with rationale.
5. **Observation**: Concrete output from the evidence step.
6. **Protected Invariant**: Explicit mathematical or structural definition of the invariant that must be maintained.
7. **Root Cause**: The exact design or code error that allowed the invariant to be broken.
8. **Repair**: The minimal, correct fix.
9. **Regression Proof**: Evidence demonstrating that the repaired program runs repeatedly, terminates cleanly, joins all worker threads, and cleanly destroys synchronization primitives without leaks or deadlocks.

## Reviewer Acceptance Criteria
- Mutexes must protect named invariants, not arbitrary code blocks.
- Multi-field state changes must not drop the mutex between linked field updates.
- Condition variable waits must use `while (predicate)` loops.
- Queue close must mark the closed state and broadcast to awaken sleeping consumers.
- All threads must be joined before `pthread_mutex_destroy` or `pthread_cond_destroy`.
- TSan output (where supported) is supporting evidence; code invariant reasoning is required.
