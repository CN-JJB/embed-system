# Fault Station F3 — Owned File Descriptor Leak

## Objective
Diagnose and isolate a file descriptor leak on an error-handling path using `/proc/<pid>/fd`.

## Prerequisites
- Linux file descriptor lifetime and ownership rules.
- Inspection of `/proc/self/fd` and POSIX `open`/`close` semantics.

## Environment
- Linux / POSIX C17 environment.
- Tool: `/proc/self/fd` (AVAILABLE), `lsof` / `strace` (if available).

## Build & Run
```bash
make build/fault_f3
./build/fault_f3
```

## Expected Observation
The open file descriptor count in `/proc/self/fd` increases linearly with each failed ingestion call:
```
Open FDs before calls: 4
Open FDs after 5 failed calls: 9
>>> F3 REPRODUCED: Owned file descriptors leaked! Leaked count=5 <<<
```

## Evidence Question
Why is `close()` mandatory on error paths? Which module in the telemetry architecture owns the file descriptor opened from a path argument, and which owns `stdin`?

## Verification Status
- **VERIFIED**: Reproduces FD count growth in `/proc/self/fd`.

## Cleanup
```bash
rm -f build/fault_f3
```
