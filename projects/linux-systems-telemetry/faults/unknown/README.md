# Unknown Fault Bounded Reproduction Fixture

## Objective
Reproduce the shutdown hang symptom safely using the bounded reproduction harness.

## Reproduction Command
```bash
make build/unknown_repro
./build/unknown_repro
```

## Expected Observation
The test launches a consumer worker thread which blocks on an empty queue. The main thread coordinates deterministically with the consumer and initiates queue shutdown.

Because of the hidden defect, the worker never awakens from its wait state. After 3 seconds, the safety watchdog fires and reports the failure:
```
=== Unknown Fault Reproduction Harness ===
[main] Worker started and waiting on queue...
[main] Initiating queue close...
>>> UNKNOWN FAULT REPRODUCED: Consumer thread remained blocked after queue close! <<<
```
Exit code: `2`.

## Diagnostic Strategy
1. Attach GDB or inspect backtraces where supported: what function and synchronization primitive is the consumer thread sleeping on?
2. Trace the shutdown sequence in source code: when the queue transition to `closed` occurs, how is the sleeping consumer notified?
3. Apply the 8-step postmortem protocol.
