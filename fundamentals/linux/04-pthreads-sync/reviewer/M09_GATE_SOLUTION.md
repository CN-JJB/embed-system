# M09 Gate Reviewer Solution & Evidence Mapping

This document provides the canonical reviewer postmortem and evidence mapping for the three seeded fault domains in `gate/gate_seeded.c`. Reference implementation is located in `reviewer/gate_solution.c`.

---

## Domain 1: Race / Unsynchronized Access

### Symptom
Running `./build/gate_seeded race` produces a final counter value strictly less than 300,000 (e.g. 182,341 instead of 300,000).

### First Evidence & Diagnostic Observation
- **First Evidence**: Run with ThreadSanitizer:
  ```bash
  gcc -std=c17 -O0 -g3 -pthread -fsanitize=thread gate/gate_seeded.c -o build/gate_tsan
  ./build/gate_tsan race
  ```
- **Observation**: TSan reports `WARNING: ThreadSanitizer: data race on global variable g_race_counter`. Both threads perform concurrent unsynchronized Read-Modify-Write instructions (`mov`, `add`, `mov`).

### Root Contract
- **Protected Invariant**: `g_race_counter == sum(increments_completed)`.
- **Root Cause**: `g_race_counter++` in C17 is not atomic. In the absence of synchronization, interleaved loads and stores cause lost updates.

### Repair
Protect the read-modify-write operation with a mutex:
```c
pthread_mutex_lock(&g_counter_lock);
g_counter++;
pthread_mutex_unlock(&g_counter_lock);
```

### Regression Proof
- Running `./build/gate_solution race` produces `counter=300000 (expected=300000)` deterministically across 100 consecutive runs.
- Running `./build/gate_solution race` under TSan reports zero data race warnings.

---

## Domain 2: Multi-Field Invariant Violation

### Symptom
Running `./build/gate_seeded invariant` triggers an assertion failure / violation log:
`>>> FAULT REPRODUCED: Invariant violation! a=4950 b=5000 sum=9950 (expected 10000) <<<`

### First Evidence & Diagnostic Observation
- **First Evidence**: Code inspection of the transfer loop in `gate_seeded.c` line 80-95.
- **Observation**: The transfer worker acquires the mutex, decrements `account_a`, releases the mutex, sleeps 1 microsecond, and only then acquires the mutex again to increment `account_b`.
- During the intermediate window, `account_a + account_b == 9950 != 10000`. The auditor thread observes this transient invalid state.

### Root Contract
- **Protected Invariant**: `account_a + account_b == TOTAL_FUNDS (10000)` at every point outside of an active internal critical section.
- **Root Cause**: Breaking a single conceptual multi-field state transition into multiple separate critical sections. The mutex protected individual variables sequentially, but failed to protect the multi-field invariant.

### Repair
Enclose the complete multi-field transaction inside a single critical section:
```c
pthread_mutex_lock(&g_fixed_bank.lock);
g_fixed_bank.account_a -= 50;
g_fixed_bank.account_b += 50;
pthread_mutex_unlock(&g_fixed_bank.lock);
```
Ensure the auditor reads both fields within `g_fixed_bank.lock`.

### Regression Proof
- Running `./build/gate_solution invariant` executes 50,000 transfer iterations and 2,000 auditor inspection passes with 0 invariant violations observed.

---

## Domain 3: Condition-Variable Predicate / Missing-Wake Bug

### Symptom
Running `./build/gate_seeded condvar` hangs indefinitely. The 2-second watchdog timer catches the hang:
`>>> FAULT REPRODUCED: Watchdog timeout! Consumer hung waiting on condvar after close. <<<`

### First Evidence & Diagnostic Observation
- **First Evidence**: Source inspection of `run_fault_condvar()` in `gate_seeded.c`:
  ```c
  pthread_mutex_lock(&g_gate_queue.mutex);
  g_gate_queue.closed = 1;
  /* OMITTED: pthread_cond_broadcast(&g_gate_queue.not_empty); */
  pthread_mutex_unlock(&g_gate_queue.mutex);
  ```
- **Observation**: The consumer thread is suspended in `pthread_cond_wait(&g_gate_queue.not_empty, &g_gate_queue.mutex)`. Although the predicate condition changed (`closed = 1`), no signal or broadcast was issued. The consumer never awakens to re-evaluate the predicate.

### Root Contract
- **Protected Invariant**: A condition variable wait must always be paired with:
  1. A predicate loop: `while (!closed && count == 0) pthread_cond_wait(&cond, &mutex);`
  2. A notification on state change: whenever a state transition occurs that could make any waiter's predicate true (including `closed = 1`), `pthread_cond_broadcast` or `pthread_cond_signal` must be invoked while holding or immediately following the mutex.
- **Root Cause**: Missing `pthread_cond_broadcast()` during state transition to `closed = 1`.

### Repair
```c
pthread_mutex_lock(&g_fixed_queue.mutex);
g_fixed_queue.closed = 1;
pthread_cond_broadcast(&g_fixed_queue.not_empty);
pthread_mutex_unlock(&g_fixed_queue.mutex);
```
Ensure the consumer predicate uses `while`:
```c
while (g_fixed_queue.count == 0 && !g_fixed_queue.closed) {
    pthread_cond_wait(&g_fixed_queue.not_empty, &g_fixed_queue.mutex);
}
```

### Regression Proof
- Running `./build/gate_solution condvar` finishes in ~25 milliseconds. The consumer wakes up, consumes the remaining element (`42`), detects `closed && count == 0`, and exits.
- `pthread_join(c, NULL)` completes without blocking.
- Mutex and condvar are cleanly destroyed with `pthread_mutex_destroy` and `pthread_cond_destroy`.
