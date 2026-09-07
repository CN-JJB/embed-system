# Fault Case F3: Sporadic Processing Latency Jitter and Missed Deadlines

## Manifested Symptom

Logic analyzer captures connected to GPIO instrumentation pins (PA1: DMA transfer milestone, PA2: Compute task activity, PA3: Health task activity, PA4: Critical lock activity) reveal sporadic, severe response latency in the acquisition pipeline.

Normally, `Task_Process` begins handling an incoming 64-sample buffer within microseconds of the DMA half-transfer interrupt. Under the faulty condition, however, `Task_Process` execution is intermittently delayed by 20 to 50 milliseconds. Consequently, buffer processing overruns into the subsequent ping-pong half, causing dropped frames and degraded signal reconstruction.

## Investigation Workflow

1. **Formulate Hypotheses**:
   Draft 3 to 5 candidate hypotheses explaining how a high-priority task (`Task_Process`, Priority 3) can be blocked or delayed by tens of milliseconds in a preemptive priority-based RTOS. Base your hypotheses strictly on the observable timing characteristics and RTOS synchronization design.
2. **Design Discriminative Observations**:
   Use multi-channel logic analyzer traces on PA1–PA4 or GDB thread backtraces captured during the latency spike to observe task scheduling states and execution timelines.
3. **Isolate Root Cause**:
   Trace the execution flow and synchronization primitives involved in the acquisition processing path to pinpoint the source of unbounded blocking.
4. **Implement Surgical Fix**:
   Implement a surgical fix that eliminates the latency jitter and guarantees deterministic sample processing within real-time deadlines.
5. **Verify**:
   Confirm that `scripts/verify_project.sh` passes.
