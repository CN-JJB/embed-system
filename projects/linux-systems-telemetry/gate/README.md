# M10 Project Acceptance Gate

**AI-Free First Pass. This is M10 Project Acceptance, not the Phase 1 Final Gate.**

To pass M10 Project Acceptance, you must provide verified evidence across all architecture, lifecycle, concurrency, and error-handling requirements. "The program compiles and runs once" is NOT sufficient.

## Required Acceptance Evidence Checklist

Your submission must provide concrete operational evidence for each of the following 12 items:

### 1. Clean Strict Build
- Flags: `-std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread`
- Command: `make clean && make`
- Must produce zero warnings and zero errors.

### 2. Protocol & Codec Verification
- Command: `./build/test_unit`
- Validates:
  - 12-octet explicit little-endian binary serialization (`telemetry_encode_record`).
  - Strict length and magic/version validation (`telemetry_decode_record`).
  - Bit-preserving signed wire decode via `memcpy` (preserving `INT32_MIN` without implementation-defined casting).

### 3. Parser & Input Boundary Validation
- Validates:
  - Parsing `<timestamp_ns>,<sensor_id>,<scaled_value>\n`.
  - Detection and rejection of missing delimiters, truncated records, empty lines, and out-of-range sensor IDs (`sensor_id > 255`).
  - Input lines exceeding buffer bounds rejected without buffer overrun.

### 4. Resource Ownership Contract (Owned vs Borrowed FDs)
Submit an explicit ownership table:
| Resource | Origin | Manager / Owner | Cleanup Responsibility |
|---|---|---|---|
| Input file FD | `argv[1]` file path | `main()` | `main()` calls `close(fd)` on all exit paths |
| Stdin FD (`STDIN_FILENO`) | Inherited environment | Process environment | `main()` borrows; MUST NOT call `close(STDIN_FILENO)` |
| Queue memory & primitives | `main()` stack | `main()` | `queue_destroy()` after worker join |
| Worker thread | `main()` | `main()` | `pthread_join()` before exit |

### 5. Bounded Ring Queue Invariants
Demonstrate the structural invariant:
- `0 <= count <= TELEMETRY_QUEUE_CAPACITY`
- `head = (tail + count) % TELEMETRY_QUEUE_CAPACITY`
- Value semantics: records are stored by value in ring buffer, eliminating caller buffer lifetime dependencies.

### 6. Concurrency Predicate Loops & Spurious Wakeup Safety
Source audit in `src/queue.c`:
- Push waits in `while (q->count == CAPACITY && !q->closed) pthread_cond_wait(&q->not_full, &q->lock);`
- Pop waits in `while (q->count == 0 && !q->closed) pthread_cond_wait(&q->not_empty, &q->lock);`
- Recheck under lock prevents lost updates or spurious wakeup crashes.

### 7. Clean Shutdown & Worker Join Before Destroy
Demonstrate that:
- `queue_close()` marks `closed = 1` and broadcasts on both condition variables.
- Worker drains remaining records and terminates upon `closed && count == 0`.
- `pthread_join(worker_tid, NULL)` is executed BEFORE `queue_destroy(&queue)` is called.

### 8. Async-Signal Safety
- Signal handler handles `SIGINT` and `SIGTERM`.
- Handler contains only async-signal-safe operations (sets volatile/sig_atomic flag `stop_requested = 1`).
- Handler does NOT call `malloc`, `free`, `pthread_mutex_lock`, `printf`, or `exit`.
- Worker thread blocks `SIGINT`/`SIGTERM` via `pthread_sigmask`; only main thread unblocks and delivers signals.

### 9. SIGTERM Shutdown with Blocked / Open Input
- Command: `./scripts/integration.sh ./build/telemetry fixtures`
- Integration test keeps a named pipe (FIFO) write end open with no incoming data.
- Service is sent `SIGTERM`.
- Service terminates cleanly without hanging, without waiting for EOF, and without leaking resources.

### 10. Normal EOF Termination
- Service reads regular file or piped input to EOF, drains queue completely, joins worker, outputs final stats, and exits code 0.

### 11. Sanitizers Execution
- `make san`: Runs complete test suite and integration tests under AddressSanitizer + UndefinedBehaviorSanitizer with zero memory leaks and zero undefined behavior.
- `make tsan`: Documents ThreadSanitizer execution status honestly on authoring environment.

### 12. Complete Unknown Fault Postmortem
- Complete diagnostic report for the unknown fault following the 8-step protocol:
  `Symptom → Own Description → 3–5 Hypotheses → First Evidence + Why → Observation → Narrow Scope → Root Cause → Fix → Regression`.
