# P2-M06 Fault Analysis: Comprehensive Learner Diagnostics

## Fixture `f1`: Binary Semaphore Used for Mutual Exclusion

### Scenario-Reported Symptom & Behavior
Task High (Priority 3) suffers massive latency spikes (>25 ms) when Task Medium (Priority 2) executes, even though Task High is supposed to have highest priority. A logic analyzer confirms that Task Medium preempts Task Low while Task Low holds the shared resource lock.

### Hypothesis Tree
1. **H1**: Task Medium was assigned Priority 4 instead of Priority 2.
2. **H2**: Task Low is voluntarily sleeping via `vTaskDelay()`.
3. **H3**: The shared lock was instantiated using `xSemaphoreCreateBinary()` instead of `xSemaphoreCreateMutex()`, eliminating priority inheritance.
4. **H4**: Task High is failing to block on the semaphore.

### Evidence
Inspecting `faults/f1/inversion_app_f1.c`:
```c
g_shared_resource = xSemaphoreCreateBinary();
xSemaphoreGive(g_shared_resource);
```
Binary semaphores have type `queueQUEUE_TYPE_BINARY_SEMAPHORE`. They do not track `pxMutexHolder` and do not invoke `xTaskPriorityInherit()` when higher-priority tasks block on them.

### Root Cause
Mutual exclusion synchronization implemented with a binary semaphore lacks priority inheritance, causing unbounded priority inversion under medium-priority interference.

### Minimal Fix
Replace `xSemaphoreCreateBinary()` with `xSemaphoreCreateMutex()` and remove the initial `xSemaphoreGive()`.

---

## Fixture `f2`: Medium Task Starvation / Watchdog Reset Loop

### Scenario-Reported Symptom & Behavior
Target reboots every ~1.0 second in an endless loop. Inspecting `RCC->CSR` in GDB shows `RCC_CSR_IWDGRSTF` set on every boot.

### Hypothesis Tree
1. **H1**: Watchdog reload value is too small.
2. **H2**: LSI oscillator is running at twice normal frequency.
3. **H3**: Task Medium does not block on notifications and monopolizes the CPU at Priority 2, starving Task Low (Priority 1) and preventing `iwdg_refresh()`.

### Evidence
In `faults/f2/inversion_app_f2.c`:
```c
static void prvTaskMedium(void *pvParameters) {
    for (;;) {
        prvMediumWorkload();
    }
}
```
`prvTaskMedium` omits `ulTaskNotifyTake()`, running continuously at Priority 2. Task Low (Priority 1), which handles watchdog refreshing, is completely starved. The IWDG down-counter expires after 1.0 second, triggering hardware reset.

### Root Cause
Unconstrained higher-priority task starves lower-priority supervisory task responsible for refreshing the hardware watchdog.

### Minimal Fix
Restore `ulTaskNotifyTake(pdTRUE, portMAX_DELAY)` in `prvTaskMedium()`.

---

## Fixture `f3`: Voluntary Delay (`vTaskDelay`) Inside Critical Section

### Scenario-Reported Symptom & Behavior
Priority inheritance is enabled via `xSemaphoreCreateMutex()`, yet Task High still experiences 20 ms latency delays while waiting for Task Low.

### Hypothesis Tree
1. **H1**: FreeRTOS mutex implementation has a kernel bug.
2. **H2**: Task Low calls a blocking API (`vTaskDelay`) while holding the mutex, voluntarily relinquishing the CPU despite its boosted priority.
3. **H3**: Interrupts are disabling the scheduler.

### Evidence
In `faults/f3/inversion_app_f3.c`:
```c
vTaskDelay(pdMS_TO_TICKS(15));
inversion_execute_low_workload();
```
Even though Task Low inherits Priority 3, calling `vTaskDelay()` moves it to the `pxDelayedTaskList`. Since Low is no longer in the Ready list, the scheduler picks the next highest ready task: Task Medium (Priority 2). Task Medium runs for 20 ms while the mutex remains locked!

### Root Cause
Voluntary blocking (`vTaskDelay`, unready I/O) inside a mutex critical section surrenders the CPU and invalidates real-time guarantees.

### Minimal Fix
Remove `vTaskDelay()` from within the critical section.

---

## Fixture `f4`: Stack Overflow and Watermark Unit Hazard

### Scenario-Reported Symptom & Behavior
Firmware crashes immediately upon scheduler launch. SWD probe finds the CPU trapped inside `vApplicationStackOverflowHook()`.

### Hypothesis Tree
1. **H1**: Heap size `configTOTAL_HEAP_SIZE` is exhausted.
2. **H2**: Task Low allocates an oversized local buffer on the stack exceeding its stack quota, corrupting the canary.
3. **H3**: SysTick ISR overflowed the MSP stack.

### Evidence
In `faults/f4/inversion_app_f4.c`:
```c
void inversion_execute_low_workload(void) {
    volatile uint8_t overflow_buffer[1024];
...
```
Task Low's allocated stack depth is 256 words (1024 bytes). Allocating a 1024-byte local buffer on top of FreeRTOS context frame (`{r4-r11, r0-r3, lr, pc, xpsr}`) immediately overwrites the 16-byte canary at the stack base. When context switch occurs, `taskCHECK_FOR_STACK_OVERFLOW()` (Method 2) detects canary corruption and vectors to `vApplicationStackOverflowHook()`.

### Root Cause
Local buffer allocation exceeded allocated task stack capacity.

### Minimal Fix
Allocate large buffers statically or in heap, or increase task stack depth to accommodate peak stack frame.

---

## Fixture `f5`: Watchdog Refresh in Unmonitored Task

### Scenario-Reported Symptom & Behavior
Application tasks are completely locked up in mutual exclusion deadlock, yet the Independent Watchdog never triggers a recovery reset.

### Hypothesis Tree
1. **H1**: IWDG was never started (`IWDG->KR = 0xCCCC` missing).
2. **H2**: Watchdog is being fed blindly from an independent task or interrupt handler that does not check application health.
3. **H3**: Hardware reset line is disconnected.

### Evidence
In `faults/f5/main_f5.c`:
```c
static void prvBlindWatchdogTask(void *pvParameters) {
    for (;;) {
        iwdg_refresh();
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}
```
A dedicated task unconditionally feeds `iwdg_refresh()` every 100 ms without auditing whether `Task_Low`, `Task_Medium`, or `Task_High` are making progress or deadlocked.

### Root Cause
Decoupled watchdog refreshing masks system lockups and defeats hardware fail-safe protection.

### Minimal Fix
Remove `prvBlindWatchdogTask`. Enforce health monitoring where `iwdg_refresh()` is only called if all application tasks have completed their work cycles within specified deadlines.
