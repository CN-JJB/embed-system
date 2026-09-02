# Fault Station F1 — Queue Field Race

## Objective
Diagnose and isolate an unsynchronized shared field access within the bounded ring queue implementation.

## Prerequisites
- Bounded ring queue synchronization invariants.
- Understanding of data races and POSIX mutex mutual exclusion.

## Environment
- Linux / POSIX C17 environment.
- Tool: GCC, ThreadSanitizer (`-fsanitize=thread`).

## Build & Run
Compile and run the station:
```bash
make build/fault_f1
./build/fault_f1
```

Or build with ThreadSanitizer:
```bash
gcc -Isrc -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread -fsanitize=thread faults/f1_queue_race/station.c -o build/fault_f1_tsan
./build/fault_f1_tsan
```

## Expected Observation
- In non-TSan run, final `queue.count` frequently diverges from 0 due to concurrent lost updates on `q->count++` and `q->count--`.
- In TSan run, TSan reports a data race on `q->count` between producer and consumer threads.

## Evidence Question
Which exact lines in `station.c` violate the queue synchronization contract? Why must `q->count` be mutated strictly within `q->lock`?

## Verification Status
- **VERIFIED**: Reproduces lost updates and triggers TSan data race warning on `q->count`.

## Cleanup
```bash
rm -f build/fault_f1 build/fault_f1_tsan
```
