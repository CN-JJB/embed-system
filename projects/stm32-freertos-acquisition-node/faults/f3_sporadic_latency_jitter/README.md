# Fault Case F3: Sporadic Processing Latency Jitter and Missed Deadlines

## Manifested Symptom

Logic analyzer captures connected to GPIO instrumentation pins (PA1: DMA transfer milestone, PA2: Compute task activity, PA3: Health task activity, PA4: Critical lock activity) reveal sporadic, severe response latency in the acquisition pipeline.

Normally, `Task_Process` begins handling an incoming 64-sample buffer within microseconds of the DMA half-transfer interrupt. Under the faulty condition, however, `Task_Process` execution is intermittently delayed by 20 to 50 milliseconds. Consequently, buffer processing overruns into the subsequent ping-pong half, causing dropped frames and degraded signal reconstruction.

## Investigation Workflow

1. **Formulate Hypotheses**:
   Draft 3 to 5 candidate hypotheses explaining how a high-priority task (`Task_Process`, Priority 3) can be blocked or delayed by tens of milliseconds in a preemptive priority-based RTOS:
   - Priority inversion or mutual exclusion lock contention on a shared resource held by lower-priority tasks.
   - Long-duration non-preemptible interrupt service routines or critical sections masking interrupts (`taskENTER_CRITICAL()`).
   - Task starvation caused by misconfigured task priorities or runaway compute loops.
   - Queue operation blocking caused by inappropriate timeout parameters or backpressure.
   - Memory allocation delays or heap fragmentation stalls.
2. **Design Discriminative Observations**:
   Use multi-channel logic analyzer traces on PA1–PA4 or GDB thread backtraces captured during the latency spike to observe which task is currently executing and what synchronization object `Task_Process` is waiting for.
3. **Isolate Root Cause**:
   Analyze the synchronization primitives accessed along the critical sample processing path and determine whether priority inheritance or unbounded lock waiting is occurring.
4. **Implement Surgical Fix**:
   Ensure the real-time acquisition fast path is completely decoupled from non-real-time mutual exclusion resources.
5. **Verify**:
   Confirm that `scripts/verify_project.sh` passes.

