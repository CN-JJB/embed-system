# Fault Case F1: Missing Telemetry Sequence Numbers with Zero Reported Drops

## Manifested Symptom

During continuous operational testing, the host console connected to USART1 (115200 baud, 8N1) monitors incoming telemetry frames. Under high data generation rates or transient serial logging congestion, the telemetry log exhibits sequence gaps:

```text
[TELEM] seq=142 min=2040 max=2055 avg=2048 rms=2048 drops=0
[TELEM] seq=146 min=2041 max=2054 avg=2048 rms=2048 drops=0
```

Notice that frames with sequences 143, 144, and 145 never arrived at the host receiver, yet the telemetry payload continues to report `drops=0`. The sequence counter continued to advance, indicating that acquisition events occurred, but the data never traversed the telemetry link and no failure was logged.

## Investigation Workflow

1. **Formulate Hypotheses**:
   Draft 3 to 5 distinct technical hypotheses explaining how a sequence counter can advance while the resulting payload is omitted from transmission without incrementing the reported drop counter. Consider:
   - Hardware transfer events and DMA interrupt firing behaviors.
   - Queue ingress and egress contracts between interrupt and task contexts.
   - Buffer memory management and ping-pong state tracking.
   - Serial transmission formatting and buffer overflow behavior.
2. **Design Discriminative Observations**:
   For each hypothesis, determine what concrete, observable evidence (e.g. GDB variable watch, register check, or instrumentation pin toggle) would confirm or refute it.
3. **Isolate Root Cause**:
   Trace the data path from hardware DMA interrupt notification to task-level queue submission and telemetry transmission.
4. **Implement Surgical Fix**:
   Ensure all acquisition dropped frames or submission failures are reliably captured and reported in telemetry.
5. **Verify**:
   Confirm that `scripts/verify_project.sh` passes.

