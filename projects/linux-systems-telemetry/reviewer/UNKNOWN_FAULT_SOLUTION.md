# Reviewer Reference — Unknown Fault Diagnosis & Solution

## Hidden Seed Specification
- **Component**: Ring queue shutdown logic (`src/queue.c:queue_close` / `faults/unknown/repro.c`).
- **Defect**: The queue close function acquires `q->lock`, sets `q->closed = 1`, and releases `q->lock`, but fails to broadcast on `q->not_empty` (`pthread_cond_broadcast(&q->not_empty)`).
- **Isolation Requirement**: This root cause must NOT be shown to learners prior to independent diagnostic submission.

## Diagnostic Postmortem Reference

### 1. Symptom
The telemetry service hangs on shutdown. Running the bounded reproduction harness `./build/unknown_repro` times out after 3 seconds:
`>>> TIMEOUT: Telemetry service shutdown hung! Process failed to exit within 3s. <<<`

### 2. Own Description
When the input stream finishes or shutdown begins, the worker thread is waiting on an empty queue. The main thread signals shutdown by closing the queue, but the worker thread remains asleep and does not terminate, blocking the main thread's `pthread_join`.

### 3. Hypotheses
1. Main thread deadlocked attempting to acquire `q->lock` in `queue_close`.
2. Worker thread entered an infinite processing loop inside `queue_pop`.
3. Worker thread is waiting on `pthread_cond_wait(&q->not_empty, ...)` and was never signaled when the queue closed.
4. Signal handler interrupted worker thread and left a mutex locked.

### 4. First Evidence & Why
- **Evidence**: Inspect thread stack traces via GDB or code inspection of `queue_close`.
- **Why**: Disambiguates whether the worker is spinning, deadlocked on a mutex, or sleeping on a condition variable.
- **Observation**: Worker thread is suspended inside `pthread_cond_wait(&q->not_empty, &q->lock)`. Main thread is suspended inside `pthread_join`.

### 5. Narrow Scope & Root Cause
- **Scope**: The state transition logic in `queue_close()`.
- **Root Cause**: Condition variable wait predicates take the form `while (count == 0 && !closed) pthread_cond_wait(...)`. When `closed` is set to `1`, the predicate condition becomes false. However, a thread in `pthread_cond_wait` does not re-evaluate its predicate until it is woken by `pthread_cond_signal` or `pthread_cond_broadcast`. Because `queue_close()` failed to broadcast, sleeping workers never re-evaluate the predicate and remain blocked indefinitely.

### 6. Fix
In `queue_close()`:
```c
pthread_mutex_lock(&q->lock);
q->closed = 1;
pthread_cond_broadcast(&q->not_empty);
pthread_cond_broadcast(&q->not_full);
pthread_mutex_unlock(&q->lock);
```

### 7. Regression Proof
Run `./build/unknown_solution`:
Executes 100 consecutive deterministic cycles verifying:
- Worker is blocked on empty queue.
- Main calls `queue_close()` with broadcast.
- Worker wakes, detects `closed && count == 0`, and exits.
- `pthread_join` returns promptly.
- `queue_destroy` succeeds without `EBUSY`.
- 100/100 passes without a single hang.
