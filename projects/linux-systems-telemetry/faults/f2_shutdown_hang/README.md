# Fault Station F2 — Shutdown Hang

## Objective
Reproduce and diagnose a process hang during shutdown caused by a missing condition variable broadcast.

## Prerequisites
- Condition variable synchronization model (`pthread_cond_wait`, `pthread_cond_broadcast`).
- Predicate evaluation loops.

## Environment
- Linux / POSIX C17 environment.
- Tool: GCC, GDB / backtrace (where available).

## Build & Run
```bash
make build/fault_f2
./build/fault_f2
```

## Expected Observation
The process blocks at `pthread_join(w, NULL)`. After 2 seconds, the watchdog fires:
```
>>> F2 REPRODUCED: Shutdown hang! Worker thread remained blocked after close. <<<
Root cause: Predicate changed to (closed=1), but sleeper was not signaled to re-evaluate.
```

## Evidence Question
If inspecting under GDB with `info threads` and `thread apply all bt`, what function is the worker thread blocked in? Why did setting `closed = 1` fail to wake it?

## Verification Status
- **VERIFIED**: Reproduces watchdog timeout on missing wake.

## Cleanup
```bash
rm -f build/fault_f2
```
