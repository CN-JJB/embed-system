# Lab 06: Queue-Full Event Dropping and Buffer Lifecycle Management

## Objective
Analyze queue overflow behavior, evaluate return values from `xQueueSendFromISR()`, implement bounded packet-drop telemetry, and size queue depth based on producer-consumer rate differentials.

## Prerequisites
- Lab 01: Queue memory model and capacity limits.
- Lab 02: Synthetic TIM2 ISR queue producer.

## Estimated Time
- 45 minutes (MUST load).

## Architectural Principles

### 1. The Queue-Full Return Contract
`xQueueSendFromISR()` returns:
- `pdPASS` (`1`): The item was successfully copied into the queue storage.
- `errQUEUE_FULL` (`0`): The queue is already full (`uxMessagesWaiting == uxLength`). The item was **not** copied and was discarded.

Because an ISR cannot block, it cannot wait for space to become available. If `xQueueSendFromISR()` returns `errQUEUE_FULL`, the firmware **must** handle the drop explicitly:
```c
BaseType_t xResult = xQueueSendFromISR(g_sample_queue, &s_seq, &xHigherPriorityTaskWoken);
if (xResult == pdPASS) {
    g_isr_sent_count++;
} else {
    /* Explicit packet drop accounting */
    g_isr_dropped_count++;
}
```

### 2. Silent Packet Loss vs Telemetry Counters
Ignoring the return value of `xQueueSendFromISR()` is an anti-pattern. If the consumer task is delayed or preempted by higher-priority tasks, the queue fills up. The ISR silently discards incoming hardware events, resulting in data loss that is undetectable without diagnostic counters.

### 3. Queue Sizing Math
Queue depth must accommodate the burst rate ($R_{\text{burst}}$) minus consumption rate ($R_{\text{consume}}$) over the maximum consumer preemption window ($T_{\text{preempt}}$):
$$L_{\text{queue}} \ge \lceil (R_{\text{burst}} - R_{\text{consume}}) \times T_{\text{preempt}} \rceil + \text{Margin}$$
For our 100 Hz timer ($T = 10\text{ ms}$), a queue depth of 10 provides up to $100\text{ ms}$ of buffer headroom if `Task_Consumer` is temporarily blocked by higher-priority work.

## Lab Procedure
1. In `src/timer.c`, locate the handling of `xResult`:
   ```c
   if (xResult == pdPASS) {
       g_isr_sent_count++;
   } else {
       g_isr_dropped_count++;
   }
   ```
2. In `src/queue_app.c`, observe how `g_consumer_sequence_errors` tracks discontiguities in `rx_val`.
3. In Fault fixture `f5`, examine how ignoring `errQUEUE_FULL` obscures data loss and leads to unmonitored telemetry failures.

> **Status**: Static code contracts and drop logic VERIFIED; physical queue saturation trace UNVERIFIED (Headless automated build).
