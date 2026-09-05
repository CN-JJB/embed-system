# Lab 03: Task Creation, Stack Frame Initialization, and Preemptive Scheduling

## Objective
Trace the internal operation of `xTaskCreate()`, examine the synthetic Cortex-M3 stack frame initialization in `pxPortInitialiseStack()`, understand why bit 24 of `xPSR` must be set, and analyze priority preemption vs round-robin time slicing.

## Prerequisites
- Lab 01: FreeRTOS kernel integration.
- Lab 02: SysTick coherence and tick generation.
- Understanding of ARM Cortex-M3 register set (R0-R15, xPSR, MSP, PSP).

## Environment
- Target: STM32F103C8T6 (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM).
- Toolchain: Arm GNU Toolchain 13.3.rel1 / Ubuntu GCC 13.2.1 cross-compiler.

## Estimated Time
- 60 minutes (MUST load).

## AI Mode
- **AI-Hint**: Socratic guidance permitted on stack frame alignment, xPSR Thumb bit requirements, and TCB list membership. Direct code generation prohibited.

## Architectural Principles

### 1. `xTaskCreate()` Allocation Anatomy
When `xTaskCreate()` is called:
```c
BaseType_t xTaskCreate(TaskFunction_t pxTaskCode,
                       const char * const pcName,
                       const configSTACK_DEPTH_TYPE usStackDepth,
                       void * const pvParameters,
                       UBaseType_t uxPriority,
                       TaskHandle_t * const pxCreatedTask);
```
Under `configSUPPORT_DYNAMIC_ALLOCATION == 1`:
1. It calls `pvPortMalloc()` to allocate the task stack:
   $$\text{Bytes allocated} = \text{usStackDepth} \times \text{sizeof(StackType\_t)} = \text{usStackDepth} \times 4\text{ bytes}$$
2. It calls `pvPortMalloc()` to allocate the Task Control Block (`TCB_t`, $\approx 84$ bytes).
3. It initializes the TCB fields: task name, priority, state list item, event list item, and stack bounds.
4. It calls `pxPortInitialiseStack()` to build a synthetic exception frame on the allocated stack so the task can be entered via normal exception exit return (`bx lr`).

### 2. Cortex-M3 Exception Stack Frame Anatomy
On Cortex-M3, when an exception occurs, the hardware automatically pushes 8 words (32 bytes) onto the active stack (PSP for tasks):

```text
Higher Memory Address (Initial Stack Base / Stack Grows Downward)
+-------------------------------------------------------------+
| xPSR       (Program Status Register, bit 24 T-bit = 1)      | <-- Hardware frame
| PC         (Task Function Entry Point: pxTaskCode)          |     (pushed/popped by hardware)
| LR         (portTASK_RETURN_ADDRESS / prvTaskExitError)     |
| R12        (General Purpose Register 12)                    |
| R3         (General Purpose Register 3)                     |
| R2         (General Purpose Register 2)                     |
| R1         (General Purpose Register 1)                     |
| R0         (Task Parameter: pvParameters passed to task)    |
+-------------------------------------------------------------+
| R11        (General Purpose Register 11)                    | <-- Software frame
| R10        (General Purpose Register 10)                    |     (pushed/popped by FreeRTOS port)
| R9         (General Purpose Register 9)                     |
| R8         (General Purpose Register 8)                     |
| R7         (General Purpose Register 7)                     |
| R6         (General Purpose Register 6)                     |
| R5         (General Purpose Register 5)                     |
| R4         (General Purpose Register 4)                     | <-- pxTopOfStack in TCB
+-------------------------------------------------------------+
Lower Memory Address
```

Total initial context size: exactly $16\text{ words} = 64\text{ bytes}$.
The top-of-stack pointer `pxTopOfStack` in the task TCB points directly to `R4` in the software-saved region.

Important architectural distinctions:
1. **Task LR slot vs Exception LR**: The `LR` value in the task's hardware frame is initialized to `portTASK_RETURN_ADDRESS` (`prvTaskExitError`), an error trap function executed only if a task function erroneously returns without calling `vTaskDelete(NULL)`. It is **not** an exception return code (`EXC_RETURN`).
2. **First-task startup (`vPortSVCHandler`)**: When the scheduler launches the first task via `SVC 0`, `vPortSVCHandler()` pops `R4-R11` from the task's initial stack, points `PSP` to the hardware frame, and derives the exception return code dynamically from the handler's entry LR:
   ```assembly
   orr r14, #0xd    /* Form EXC_RETURN (0xFFFFFFFD: Thread mode, PSP) */
   bx  r14          /* Hardware unrolls R0-R3, R12, LR, PC, xPSR into CPU */
   ```
   No `EXC_RETURN` word is ever stored on the task stack.
3. **Subsequent context switches (`PendSV_Handler`)**: During later context switches, `PendSV_Handler` saves the active exception `r14` (`EXC_RETURN`) on the **MSP** (`stmdb sp!, {r3, r14}`) across the call to `vTaskSwitchContext()`, and restores it from MSP. The exception return value is exception-handler state on MSP, not a permanent word in the task's PSP stack.
4. **Privilege Mode**: Standard non-MPU FreeRTOS tasks execute in **privileged Thread mode using PSP**.

### 3. The Critical `xPSR` Thumb Bit (Bit 24)
Cortex-M3 only supports the **Thumb-2** instruction set; it has no legacy 32-bit ARM instruction execution mode.
The `xPSR` register format:
- Bits [31:28]: Flags (`N`, `Z`, `C`, `V`).
- Bit 24: **Thumb bit (`T`)**.
- Bits [8:0]: Active Exception Number (IPSR).

When the processor executes an exception return (`bx lr`), the hardware unrolls the hardware frame and restores `xPSR`. If bit 24 (`T` bit) is `0`:
$$\text{xPSR[24]} == 0 \implies \text{UsageFault: Invalid State Exception (INVSTATE)}$$
The processor attempts to decode instructions in ARM mode, which is unimplemented on Cortex-M, immediately causing a fatal HardFault/UsageFault loop!

In `port.c`, `pxPortInitialiseStack()` explicitly ensures:
```c
#define portINITIAL_XPSR ( 0x01000000 )
*pxTopOfStack = portINITIAL_XPSR;
```
This sets bit 24 to `1`, guaranteeing Thumb execution.

### 4. Preemptive Scheduling vs Round-Robin Time-Slicing
- **Preemption**: When a higher-priority task transitions from `Blocked` to `Ready` (e.g. timeout expires in SysTick), FreeRTOS sets `xYieldPending = pdTRUE` and requests PendSV. The currently running lower-priority task is preempted immediately at the SysTick boundary without waiting for its time slice to end.
- **Round-Robin Time-Slicing**: When multiple tasks share the same priority level, each SysTick interrupt calls `taskSELECT_HIGHEST_PRIORITY_TASK()`, which advances the ready list pointer:
  $$\text{listGET\_OWNER\_OF\_NEXT\_ENTRY()}$$
  Each task executes for exactly one kernel tick ($1\text{ ms}$) in turn.

## Step-by-Step Procedure

1. **Review Task Creation in `src/main.c`**:
   Two tasks are registered:
   - `vHeartbeatTask` (Priority 2, Stack 128 words = 512 bytes).
   - `vMonitorTask` (Priority 1, Stack 128 words = 512 bytes).
2. **Inspect Initial Stack Builder in `port.c`**:
   Search for `pxPortInitialiseStack` in `../vendor/freertos/portable/GCC/ARM_CM3/port.c`.
   Observe how `portINITIAL_XPSR` (`0x01000000`), `pxCode`, `prvTaskExitError`, and `pvParameters` are placed onto the stack.
3. **Trace Preemption Flow**:
   - Priority 2 `vHeartbeatTask` runs.
   - It calls `vTaskDelay(pdMS_TO_TICKS(100))`. FreeRTOS removes it from `pxReadyTasksLists[2]` and places it into `pxDelayedTaskList`.
   - FreeRTOS switches context to Priority 1 `vMonitorTask`.
   - Exactly 100 ticks later, `xTaskIncrementTick()` in `SysTick_Handler` detects the delay expiration, unblocks `vHeartbeatTask`, places it back into `pxReadyTasksLists[2]`, and triggers `portYIELD_WITHIN_API()`.
   - PendSV interrupts `vMonitorTask` and switches back to `vHeartbeatTask`.

## Expected Observations & Verification
- Statically verified `main.c` task creations with explicit priorities.
- `xPortPendSVHandler` called when higher priority task unblocks.
- Zero HardFaults caused by missing Thumb bit.

## Actual Verification Status
- **Static Code & Architecture Verification**: **VERIFIED** on host cross-compiler.
- **Dynamic Task Preemption Trace via GDB**: **UNVERIFIED** (Headless build environment; no physical target attached).
