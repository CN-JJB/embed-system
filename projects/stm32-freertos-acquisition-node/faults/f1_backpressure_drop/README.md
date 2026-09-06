# Fault Case F1: Queue Backpressure & Silent Drop Loss

## Symptom
Under heavy telemetry logging load or slow serial transmission, external monitors observe non-monotonic sequence jumps in received frames:
```text
[TELEM] seq=142 min=2040 max=2055 avg=2048 rms=2048 drops=0
[TELEM] seq=146 min=2041 max=2054 avg=2048 rms=2048 drops=0
```
Notice that frames 143, 144, and 145 never arrived, yet `drops=0` is reported.

## Diagnostic Steps
1. Inspect the DMA ISR return code handling:
   - Does the ISR record failure when `xQueueSendFromISR` returns `errQUEUE_FULL` (`!pdPASS`)?
   - Is `g_acq_drops` incremented or silently discarded?
2. Inspect queue capacity:
   - Is `xAcqQueue` or `xLogQueue` sized appropriately for burst latencies?
3. Verify that the consumer tasks (`Task_Process` and `Task_Comm`) drain queues within the ping-pong half-transfer deadline (~64 ms at 1 kHz).

## Resolution Contract
The ISR must detect `errQUEUE_FULL`, increment `g_acq_drops`, and propagate the cumulative drop count to telemetry frames so downstream monitoring detects backpressure.
