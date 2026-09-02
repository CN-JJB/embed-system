# M09 Fault Campaign
- **F1 unsynchronized counter/shared access:** conflicting accesses lack synchronization; use TSan where available plus source invariant reasoning.
- **F2 TOCTOU shared-state bug:** check `count < capacity` outside the mutex, then act later; the check/action pair does not preserve the queue invariant.
- **F3 `if` wait:** replace `while (count==0 && !closed)` with `if`; broadcast/close or other wakeups can resume a thread that must re-check.
- **F4 context lifetime:** pass a pointer to context whose lifetime ends before worker use/join.
- **F5 lock misuse:** self-lock the ERRORCHECK fixture or construct an AB/BA lock-order worksheet. Diagnostic behavior is not portable proof for ordinary mutexes.

For every station: Symptom → Own Description → 3–5 Hypotheses → First Evidence + Why → Observation → Root Cause → Fix → Regression. Do not golden scheduler-dependent output.
