# Fault Fixture F2: Execution Freeze on Interrupt

## Symptom
Firmware boots and executes normally until the first timer event occurs. Immediately thereafter, the main thread stops executing and the processor remains permanently trapped.

## Task
1. Trace the processor execution state upon interrupt entry and exit.
2. Formulate 3–5 hypotheses regarding why Thread mode never resumes execution.
3. Identify the hardware interrupt handshaking requirement between peripheral and core NVIC.
4. Apply the minimal fix and verify uninterrupted periodic execution.

## Build
```bash
make clean && make
```
