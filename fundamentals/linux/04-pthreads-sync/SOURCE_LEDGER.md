# P1-M09 Source Ledger

Checked: 2026-09-01. Source hierarchy follows repository policy: primary specification/manual first, then verified upstream implementation.

| ID | Source | Org | Tier | Version/tag/commit | Exact path/section | URL | License/provenance | Teaching question | Priority | Version risk |
|---|---|---|---|---|---|---|---|---|---|---|
| M09-S1 | pthread_create(3) | Linux man-pages | T0 | man-pages 6.18 | pthread_create(3) | https://man7.org/linux/man-pages/man3/pthread_create.3.html | man-pages project | What is inherited/shared and what lifetime does arg require? | REQUIRED | low |
| M09-S2 | pthread_join(3) | Linux man-pages | T0 | man-pages 6.18 | pthread_join(3) | https://man7.org/linux/man-pages/man3/pthread_join.3.html | man-pages | When is worker lifetime complete? | REQUIRED | low |
| M09-S3 | pthread_mutex_* | Linux man-pages | T0 | man-pages 6.18 | pthread_mutex_init(3), pthread_mutex_lock(3p) | https://man7.org/linux/man-pages/man3/pthread_mutex_init.3.html | man-pages/POSIX references | Which invariant is serialized? | REQUIRED | low |
| M09-S4 | pthread_cond_* | Linux man-pages | T0 | man-pages 6.18 | pthread_cond_wait(3), pthread_cond_broadcast(3p) | https://man7.org/linux/man-pages/man3/pthread_cond_wait.3.html | man-pages/POSIX references | Why must predicate be rechecked? | REQUIRED | low |
| M09-S5 | ThreadSanitizer | GCC manual | T0 | GCC 14.2.0 authoring; docs current checked | Instrumentation Options `-fsanitize=thread` | https://gcc.gnu.org/onlinedocs/gcc/Instrumentation-Options.html | GNU FDL/GPL project docs | What race evidence does TSan provide and what are limits? | REQUIRED | medium |
| M09-S6 | musl pthread_cond_wait.c | musl | T1 upstream | v1.2.5 | src/thread/pthread_cond_wait.c | https://git.musl-libc.org/cgit/musl/tree/src/thread/pthread_cond_wait.c?h=v1.2.5 | MIT | Bounded walkthrough: where does a real libc bridge predicate waiting to lower-level synchronization? | SHOULD | medium |

The Phase 1 Linux man-pages teaching baseline remains 6.18 for consistency with the already-canonical M08 material. Newer man-pages releases may exist; they are not silently substituted into this batch.

Upstream walkthrough scope is deliberately bounded: identify API boundary, waiter bookkeeping, cancellation/cleanup concerns, and lower-level wait/wake handoff. Do not infer user-level predicate semantics from internal implementation details and do not expand into futex/libc internals.
