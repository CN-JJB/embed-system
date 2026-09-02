# P1-M09 — pthread, Shared State, Mutex, Race, Lock Misuse

> Phase 1 / M09 · Target **L3**, L4-local only for practiced race/lock/predicate faults · 6 h MUST. Gate, challenge first pass, and fault diagnosis are **AI-Free**.

## Why
A thread is not a small process. Threads have distinct execution contexts and stacks but share the process address space and many process resources. The useful reasoning chain is `shared state -> invariant -> synchronization -> predicate -> lifecycle -> evidence`.

## Mental model
- `pthread_create` starts a distinct execution context; `pthread_join` establishes lifecycle completion and retrieves termination status.
- The `void *arg` pointer transports context; it does not extend the pointed object's lifetime. Context must remain valid until the worker no longer uses it.
- A data race is conflicting unsynchronized access, not merely “wrong output.” One apparently correct run proves nothing about race freedom.
- A mutex protects a **named invariant**. Object ownership and mutex ownership are different concepts.
- `volatile` is not pthread synchronization and does not create atomicity, mutual exclusion, or a happens-before relation.
- A condition variable is used with a mutex and a predicate. Wait in `while (!predicate)` because wakeup means “re-check,” not “predicate is true.”
- Closing a queue changes the predicate: no new push; `closed && empty` terminates the consumer; close wakes waiters.

## Labs
1. `labs/01-resource-model` — shared object, distinct thread execution, context lifetime, join.
2. `labs/02-lost-update` — unsynchronized counter and repeated execution; TSan where available.
3. `labs/03-mutex-repair` — invariant: counter changes only while mutex held.
4. `labs/04-shared-stats` — coherent `count + sum` snapshot under one lock contract.
5. `labs/05-condvar-predicate` — bounded producer/consumer queue, `while`, close + empty termination.
6. `labs/06-lock-misuse` — `PTHREAD_MUTEX_ERRORCHECK` self-lock diagnostic fixture; runtime/portability limits disclosed.

## Challenge and Gate
`challenge/` implements the AI-Free Shared Statistics Contract: count/sum/min/max/initialized plus an internal mutex, no global lock and no direct protected-member reads. `gate/` is the AI-Free Shared State & Predicate Audit. `faults/` seeds F1–F5 from the issue; `reviewer/` contains a three-level hint ladder and gate solution.

## TSan evidence
Build TSan separately from ASan. TSan reports are runtime evidence for executed paths; silence is not a proof that all schedules are race-free. In the authoring environment for this implementation GCC 14.2.0 TSan compiled and executed the project tests; details live in the implementation notes.

## Career relevance
Mutex invariants, context lifetime, wait predicates, close semantics, and disciplined teardown transfer directly to Linux userspace services and later driver/RTOS concurrency work without pretending this module teaches atomics, lock-free algorithms, semaphores, rwlocks, or scheduling policy.

## Sources
See `SOURCE_LEDGER.md` for exact source/version/section pins and provenance.
