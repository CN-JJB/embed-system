# Linux Systems Telemetry Service

## What it does
Reads bounded text telemetry records from an owned file FD or borrowed stdin, validates them, sends fixed records by value through a bounded ring buffer to one worker thread, computes statistics, and shuts down cleanly on EOF, SIGINT, or SIGTERM.

## Architecture
`input FD -> validated text parser / explicit LE codec -> telemetry_record -> bounded ring -> one worker -> stats -> final status`

## Data model
```c
struct telemetry_record { uint8_t version, kind; uint16_t flags; int32_t value; uint32_t sequence; };
```
The worker reports count, checked `int64_t` sum, min, max, and mean. If sum would overflow `int64_t`, the worker fails instead of silently wrapping.

## Wire format
The explicit binary codec is exactly 12 octets, little-endian: version@0 u8, kind@1 u8, flags@2 u16 LE, value@4 i32 LE, sequence@8 u32 LE. Raw-struct serialization is forbidden. Compilation rejects hosts where `CHAR_BIT != 8`.

## Text grammar
`KIND FLAGS VALUE SEQUENCE`, one record per line. Lines are bounded to 128 bytes, exactly four tokens are required, numeric conversion rejects range errors and trailing garbage, and no silent truncation is performed.

## Module map
- `src/parser.*`: FD byte/line boundary and callback sink.
- `src/codec.*`: explicit 12-octet LE codec.
- `src/queue.*`: fixed-capacity FIFO, mutex, two condition variables, close semantics.
- `src/stats.*`: worker-exclusive statistics.
- `src/main.c`: FD ownership, thread/signal lifecycle, final status.
- `tests/` + `scripts/`: unit-style and integration verification.

## Ownership model
| Resource | Owner | Release |
|---|---|---|
| `STDIN_FILENO` for `--input -` | caller/environment | borrowed; service does not close |
| FD opened for `--input PATH` | service main | close after join/queue teardown path |
| queue synchronization | service main | destroy only after worker join |
| records in queue | queue by value | no per-record allocation |
| worker stats | worker until exit; main reads after join | automatic object lifetime in main context |

## Queue invariants
`0 <= count <= QUEUE_CAPACITY`; `head` and `tail` are always below capacity; empty means pop cannot produce; full means push waits; closed means no new push; `closed && count==0` terminates pop. Push/pop check predicates under the mutex and wait in `while` loops. Close is idempotent, sets `closed` under lock, and broadcasts both sides.

## Thread model
Exactly one worker. Main parses and pushes. Worker pops and updates stats. Main never reads stats until `pthread_join`, so no redundant stats mutex is used.

## Shutdown model
Before worker creation, main blocks SIGINT/SIGTERM so the worker inherits the blocked mask. Main installs a minimal handler, starts the worker, then unblocks those signals only in main. The handler only preserves `errno` and sets a `volatile sig_atomic_t` flag. It does not use stdio, mutexes, condition variables, queue close, join, allocation, or cleanup. A signal interrupting blocking input causes normal-context shutdown: close queue -> wake -> drain accepted records -> worker exits -> join -> destroy synchronization -> close owned FD. `sig_atomic_t` is only signal-handler communication; mutex/condvar synchronize pthread shared state.

## Milestones
M0 contracts/ownership/sample input (~0.5h); M1 parser + multi-file Make (~1.5h); M2 FD lifecycle (~1.5h); M3 meaningful parser sink callback/context (~1h); M4 explicit binary boundary (~1h); M5 bounded ring + one worker (~2h); M6 signal shutdown + observability + fault postmortem (~2h); M10 Project Acceptance (~1h). These are the canonical learner path added now, not a claim that M0–M4 were historically executed earlier.

## Build
`make` uses C17, `-O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread`.

## Run
`./build/telemetry --input fixtures/valid.txt` or pipe input to `./build/telemetry --input -`.

## Tests
`make test` runs parser valid/malformed/range checks, 12-octet codec golden/short/version checks, FIFO/full-wait/close/wakeup queue tests, file/stdin/invalid/repeated/EOF integration, final stats, and SIGTERM while the FIFO remains open. Bounded polling is only harness coordination for handler readiness, not the correctness proof.

## Debug
Use invariant/predicate reasoning first. ASan/UBSan are `make san`; TSan is separately `make tsan`. `/proc/<pid>/fd` is suitable for owned-FD audits; strace may supplement lifecycle evidence when installed.

## Fault postmortem
`faults/` defines queue-race, shutdown-hang, FD-leak, and bad-record-boundary stations plus one AI-Free unknown fault. Each uses Symptom -> Own Description -> 3–5 Hypotheses -> First Evidence + Why -> Observation -> Narrow Scope -> Root Cause -> Fix -> Regression.

## Build / Run / Debug Notes
This project is intentionally small and uses only the C/POSIX/Linux interfaces needed to expose ownership, representation, concurrency, and shutdown contracts. Build with `make`; the normal binary is `build/telemetry`. Text input can come from a named file, which the service opens and owns, or from `-`, which borrows standard input. The parser accepts exactly four bounded numeric fields and sends each validated record through a real callback/context boundary to the queue. The one worker drains records and owns statistics updates until join. For debugging, begin with the violated contract: parser/bytes for malformed records, queue invariants and predicates for hangs, and FD ownership for leaks. `make san` uses ASan plus UBSan; `make tsan` is separate because TSan must not be combined with ASan. In the authoring environment, strict build, tests, ASan/UBSan, TSan, and SIGTERM-with-open-FIFO were executed successfully; GDB and strace were not installed, so no transcript for them is claimed. The signal handler itself only sets a `sig_atomic_t` flag; all queue close, wake, join, and cleanup work occurs in normal control flow.

## Known limitations
Linux/POSIX pthreads are assumed; runtime binary-file ingestion is not exposed as CLI, though the canonical codec is implemented/tested. No event loop, multiple workers, sockets, daemonization, JSON, database, or production metrics framework.

## Non-goals
No Phase 1 Final Gate, atomics/memory_order, rwlocks, semaphores curriculum, spinlocks, lock-free queue, detached workers, worker pool, systemd, TCP/TLS/HTTP, epoll/select/poll, CMake/autotools, or Unix-domain socket baseline.

## Career relevance
The artifact practices the small contracts repeatedly encountered in Embedded Linux/BSP/userspace support code: FD ownership, explicit binary layout, callback context, bounded queues, predicate-based blocking, worker lifetime, signals, cleanup, and evidence-driven debugging.

## Sources
See `SOURCE_LEDGER.md`.
