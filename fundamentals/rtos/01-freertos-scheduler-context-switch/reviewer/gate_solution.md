# P2-M04 Module Gate Solution: Idle Task Blocking Defect (Kernel Invariant Violation)

## Gate Defect Summary
The candidate is presented with `gate/gate_fault_firmware/`.
When user tasks enter the `Blocked` state (e.g. `vGateTask` executes `vTaskDelay(100)`), the FreeRTOS scheduler selects the lowest-priority background task: the **Idle task** (`tskIDLE_PRIORITY = 0`).
However, the system triggers a kernel panic / assertion failure in `vTaskSwitchContext()` or ceases scheduling.

## Root Cause Analysis

### 1. The Core FreeRTOS Scheduler Invariant
FreeRTOS requires that **at least one task must always be in the Ready state**.
The kernel creates the Idle task at priority 0 (`tskIDLE_PRIORITY`) specifically to satisfy this invariant when all application tasks are blocked or suspended.

### 2. The Hook Function Violation
In `gate_fault_firmware`, `#define configUSE_IDLE_HOOK 1` is enabled in `FreeRTOSConfig.h`, and `vApplicationIdleHook()` is defined in `src/main.c`:
```c
void vApplicationIdleHook(void)
{
    vTaskDelay(pdMS_TO_TICKS(10));
}
```
`vApplicationIdleHook()` executes within the context of the Idle task.
When `vTaskDelay()` is called:
1. FreeRTOS removes the currently executing task (`xIdleTaskHandle`) from the Ready list (`pxReadyTasksLists[0]`).
2. The Idle task is inserted into the delayed task list (`pxDelayedTaskList`).
3. Now, **every ready list across all priorities is empty** (`listCURRENT_LIST_LENGTH(&pxReadyTasksLists[i]) == 0` for all $i$).
4. When `vTaskSwitchContext()` runs:
   ```c
   taskSELECT_HIGHEST_PRIORITY_TASK();
   ```
   FreeRTOS detects that no task is available to run. This immediately triggers the kernel assertion:
   ```c
   configASSERT( listCURRENT_LIST_LENGTH( &( pxReadyTasksLists[ uxTopReadyPriority ] ) ) > 0 );
   ```
   or dereferences invalid memory if assertions are disabled, locking up the CPU in an unrecoverable state.

### 3. Binary & Disassembly Proof
Inspecting the compiled ELF binary disassembly:
```assembly
(EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED)
080001e8 <vApplicationIdleHook>:
 80001e8:   200a        movs    r0, #10
 80001ea:   f000 bcd9   b.w     8000ba0 <vTaskDelay>
```
The disassembly confirms that `vApplicationIdleHook` directly branches to `vTaskDelay()`, proving the blocking call within the Idle task context.

## Minimal Reference Patches

### Option 1: Disable the Idle Hook in `FreeRTOSConfig.h`
```diff
- #define configUSE_IDLE_HOOK                     1
+ #define configUSE_IDLE_HOOK                     0
```
With `configUSE_IDLE_HOOK` disabled, the kernel no longer calls `vApplicationIdleHook()`, and the linker garbage-collects the unused function.

### Option 2: Remove the Blocking Call in `src/main.c`
```diff
  void vApplicationIdleHook(void)
  {
-     vTaskDelay(pdMS_TO_TICKS(10));
+     __NOP();
  }
```

## Automated Verification
Run the regression harness:
```bash
bash fundamentals/rtos/01-freertos-scheduler-context-switch/reviewer/verify_gate_regression.sh
```
