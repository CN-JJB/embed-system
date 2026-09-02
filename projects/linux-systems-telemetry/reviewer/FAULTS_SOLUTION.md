# M10 Fault Campaign Reviewer Solutions

This document details the diagnosis, root causes, repairs, and regression criteria for the four fault stations F1–F4.

---

## F1: Queue Field Race (`faults/f1_queue_race/`)

- **Symptom**: Under concurrent push and pop operations, the queue counter `q->count` becomes corrupted, leading to lost updates or negative/overflowed queue counts.
- **First Evidence**:
  ```bash
  gcc -Isrc -std=c17 -O0 -g3 -pthread -fsanitize=thread faults/f1_queue_race/station.c -o build/fault_f1_tsan
  ./build/fault_f1_tsan
  ```
  TSan reports data race on `q->count` at lines `q->count++` and `q->count--`.
- **Root Cause**: `q->count` was modified outside of `q->lock`. In C17, unsynchronized operations on shared variables invoke undefined behavior and cause lost updates.
- **Repair**: Move `q->count++` and `q->count--` inside the critical section before `pthread_mutex_unlock(&q->lock)`.
- **Regression**: Repaired queue maintains `0 <= q->count <= CAPACITY` across 100,000 operations with zero TSan warnings.

---

## F2: Shutdown Hang (`faults/f2_shutdown_hang/`)

- **Symptom**: Telemetry ingestion process hangs indefinitely when shutting down.
- **First Evidence**:
  - Process blocks in `pthread_join(w, NULL)`.
  - Watchdog timer catches the hang after 2 seconds.
  - GDB backtrace shows worker thread waiting in `pthread_cond_wait(&q->not_empty, &q->lock)`.
- **Root Cause**: `queue_close()` set `closed = 1` inside `q->lock`, but omitted `pthread_cond_broadcast(&q->not_empty)`. Sleeping consumers wait indefinitely on the condition variable because they are never signaled to re-evaluate the predicate `while (count == 0 && !closed)`.
- **Repair**: Call `pthread_cond_broadcast(&q->not_empty)` and `pthread_cond_broadcast(&q->not_full)` within `queue_close()` under the mutex.
- **Regression**: Closed empty queue immediately wakes all sleeping worker threads, allowing them to exit and join cleanly.

---

## F3: Owned File Descriptor Leak (`faults/f3_fd_leak/`)

- **Symptom**: Service leaks file descriptors over time when encountering malformed files, eventually leading to `EMFILE` (Too many open files).
- **First Evidence**: Inspect `/proc/<pid>/fd` before and after failed ingest calls:
  ```bash
  ls -l /proc/self/fd
  ```
  The count of active file descriptors increases with every rejected input file.
- **Root Cause**: Early error return paths omitted `close(fd)`. The caller that opened the file descriptor is responsible for closing it on all return paths.
- **Repair**: Ensure every error path performs `close(fd)` before returning, or structure cleanup using an error exit label (`goto cleanup`).
- **Regression**: Open FD count in `/proc/self/fd` remains constant before and after failed operations.

---

## F4: Bad Record Boundary (`faults/f4_bad_boundary/`)

- **Symptom**: Ingestion rejects truncated binary frames or malformed text lines with error codes.
- **First Evidence**: Byte-level examination (`hexdump -C` or unit test assertion).
- **Root Cause**: Input source delivered fewer than 12 octets for binary wire format, or text input omitted required delimiters, or sensor values exceeded valid bounds (`sensor_id > 255`).
- **Repair**: Enforce strict length and range checks in `telemetry_decode_record` and `parse_text_line`:
  - Wire decode rejects `len < 12` with `CODEC_SHORT_BUFFER`.
  - Wire decode rejects `version != 1` with `CODEC_BAD_VERSION`.
  - Parser rejects missing delimiters with `PARSER_BAD_FORMAT` and out-of-range values with `PARSER_RANGE_ERROR`.
- **Regression**: Unit tests in `tests/test_unit.c` pass for all boundary cases.
