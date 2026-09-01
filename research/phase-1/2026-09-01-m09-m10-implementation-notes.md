# P1-M09 + P1-M10 Implementation Notes — 2026-09-01

## Canonical start
- Start `main`: `83e6e87a793001a14a3f2e07ec98dbe5b4a82e36`.
- Open PRs at start: none.
- Branch: `tutorial/p1-m09-m10`.
- Issue: #8.
- The implementation adds the canonical M10 milestone path now; it does not claim M0–M4 were historically executed during earlier weeks.

## Authoring environment
- Linux container, x86_64-class host environment.
- GCC: **14.2.0** — AVAILABLE + EXECUTED.
- GNU Make: **4.4.1** — AVAILABLE + EXECUTED.
- GDB: **UNAVAILABLE** in authoring environment; commands remain UNVERIFIED.
- strace: **UNAVAILABLE** in authoring environment; trace paths remain UNVERIFIED.
- `/proc`: AVAILABLE; integration coordination observed `/proc`, but exact PID/FD values are not golden evidence.
- ASan + UBSan: **AVAILABLE + EXECUTED**, `make san` passed.
- TSan: **AVAILABLE + EXECUTED**, separate `make tsan` passed for M10 project tests on this environment. No claim is made that silence proves all schedules race-free.

## M09 verification matrix
| Item | Status | Evidence |
|---|---|---|
| six labs strict compile | VERIFIED | `make` with C17/Werror/pthread passed |
| resource model lab | VERIFIED | shared object address/lifecycle exercise executed |
| lost-update race runtime outcome | PARTIALLY VERIFIED | code compiled; scheduler-dependent numeric result is intentionally not golden |
| mutex repair | VERIFIED | repeated critical-section implementation executed in test target |
| shared stats | VERIFIED | coherent count/sum exercise executed |
| condvar predicate/close | VERIFIED | queue drain/close/join exercise executed |
| ERRORCHECK misuse fixture | VERIFIED | authoring runtime returned EDEADLK; portability limits documented |
| TSan seeded lost-update race | VERIFIED | separate M09 `make tsan` executed; TSan reported a data race on global `counter`; exact formatting/PID/thread IDs are not golden evidence |
| GDB thread commands | UNVERIFIED | GDB unavailable |

## M10 verification matrix
| Item | Status | Evidence |
|---|---|---|
| strict build | VERIFIED | `make` passed with required flags |
| parser valid/malformed/range | VERIFIED | unit test passed |
| codec golden/short/version | VERIFIED | 12-octet unit checks passed |
| queue FIFO/full-wait/close/wakeup | VERIFIED | unit tests passed |
| text file/stdin/invalid/repeated/EOF | VERIFIED | integration script passed |
| worker join/final stats | VERIFIED | integration outputs matched deterministic expected stats |
| SIGTERM with input still open | VERIFIED | named FIFO write side intentionally held open; readiness bounded-poll coordinated handler installation; SIGTERM interrupted input and service exited without EOF |
| ASan/UBSan | VERIFIED | `make san` exit 0 |
| TSan separate build | VERIFIED | `make tsan` exit 0 |
| strace lifecycle | UNVERIFIED | strace unavailable |
| GDB thread debugging | UNVERIFIED | GDB unavailable |
| FD ownership reasoning | VERIFIED in code/review; `/proc` exact values not golden | owned path close and borrowed stdin contracts documented |

## Known limitations
- CLI accepts text runtime input only; explicit binary codec is implemented and tested but no binary CLI mode is added.
- One worker and one bounded in-process queue only.
- No sockets, daemonization, systemd, worker pool, event loop, JSON, database, production logging, or Phase 1 Final Gate.

## Source pins
Current teaching pins: Linux man-pages 6.15 pthread/signal/FD pages; GCC instrumentation manual with authoring GCC 14.2.0; GNU Make manual with authoring Make 4.4.1; musl v1.2.5 `src/thread/pthread_cond_wait.c` for one bounded upstream concurrency walkthrough. URLs/teaching questions/provenance are recorded in each module SOURCE_LEDGER.
