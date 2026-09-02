# M10 Fault Campaign

The M10 Fault Campaign consists of four runnable fault stations located in dedicated subdirectories:

1. **Station F1 — Queue Race** (`faults/f1_queue_race/`):
   Demonstrates lost updates and data races caused by unsynchronized access to shared queue fields. Verified with ThreadSanitizer.
2. **Station F2 — Shutdown Hang** (`faults/f2_shutdown_hang/`):
   Demonstrates a shutdown hang where predicate state changes but sleeping consumers are not awakened. Bounded by a watchdog timer.
3. **Station F3 — Owned FD Leak** (`faults/f3_fd_leak/`):
   Demonstrates file descriptor leakage on error-handling return paths, inspected via `/proc/self/fd`.
4. **Station F4 — Bad Record Boundary** (`faults/f4_bad_boundary/`):
   Demonstrates byte-level boundary verification (truncated frames, delimiter errors, range errors) where parser/codec evidence is required.

## Building and Running
Compile all fault stations:
```bash
make faults
```

Run each station:
```bash
./build/fault_f1
./build/fault_f2
./build/fault_f3
./build/fault_f4
```

For each station, follow the diagnostic postmortem format:
`Symptom → Own Description → 3–5 Hypotheses → First Evidence + Why → Observation → Root Cause → Fix → Regression`.
Do not fabricate race, deadlock, FD, PID, sanitizer, or trace output.
