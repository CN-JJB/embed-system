# Lab 02: Deterministic Priority Inversion Reproduction

## Objectives
- Construct a reproducible, deterministic 3-task priority inversion test harness.
- Enforce identical CPU-runnable workloads across tasks without using `vTaskDelay()`.
- Measure the timing penalty inflicted on a high-priority task by medium-priority interference.

## The Flawed Experiment Anti-Pattern

Many textbook examples simulate task execution using `vTaskDelay()`:
```c
/* FLAWED ANTI-PATTERN */
void prvTaskLow(void *pvParameters) {
    xSemaphoreTake(xSem, portMAX_DELAY);
    vTaskDelay(pdMS_TO_TICKS(5)); /* BUG: RELINQUISHES CPU! */
    xSemaphoreGive(xSem);
}
```
**Why this fails:** Calling `vTaskDelay()` moves the task to the `Blocked` state and yields the CPU to other tasks because it is idling, NOT because it was preempted! This fundamentally masks the true preemption mechanics of priority inversion.

## The Deterministic Workload Model

In `src/inversion_app.c`, the tasks execute pure CPU integer arithmetic:
```c
void inversion_execute_cpu_workload(uint32_t iterations) {
    volatile uint32_t acc = 0x12345678;
    for (uint32_t i = 0; i < iterations; i++) {
        acc = (acc ^ 0xA5A5A5A5) + (i * 31);
    }
}
```
At 72 MHz:
- `INVERSION_LOW_WORKLOAD_ITERATIONS` (50,000) $\approx 5\text{ ms}$ of continuous CPU execution.
- `INVERSION_MEDIUM_WORKLOAD_ITERATIONS` (200,000) $\approx 20\text{ ms}$ of continuous CPU execution.

## Run A Execution Trace (Binary Semaphore / No Inheritance)

1. `Task_Low` (Prio 1) acquires `xSharedLock` and raises GPIO `PA1`.
2. `Task_Low` signals `Task_High` (Prio 3) via task notification.
3. `Task_High` unblocks, immediately preempts `Task_Low`, and asserts GPIO `PA3`.
4. `Task_High` attempts `xSemaphoreTake(xSharedLock)`. Because `xSharedLock` is held by Low, High blocks.
5. Control returns to `Task_Low` (PA1 still high).
6. Before continuing its critical work, Low signals `Task_Medium` (Prio 2).
7. `Task_Medium` unblocks. Since Priority 2 > Priority 1, Medium **preempts** Low!
8. `Task_Medium` asserts `PA2` and burns 20 ms of pure CPU time.
9. `Task_High` (Priority 3) sits completely stalled in the `Blocked` list for over 20 ms!
10. Once Medium finishes, Low finishes its remaining workload (~5 ms total), gives the semaphore, and High finally unblocks.

**Total Delay Experienced by Task High:**
$$T_{\text{delay}} \approx T_{\text{Medium Workload}} + T_{\text{Low Workload}} \approx 20\text{ ms} + 5\text{ ms} = 25\text{ ms}$$

High is transitively delayed by Medium, an unrelated lower-priority task.

## Review Questions
1. Why must `inversion_execute_cpu_workload` use `volatile uint32_t`?
   *(Answer: Without `volatile`, GCC `-O2` optimization will eliminate the loop entirely as dead code).*
2. What would happen if a second medium task (Priority 2) also became ready during this interval?
   *(Answer: The delay experienced by High would increase further, demonstrating why priority inversion is unbounded in general).*
