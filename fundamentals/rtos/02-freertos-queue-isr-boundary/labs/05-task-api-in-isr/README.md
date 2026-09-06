# Lab 05: Task API vs FromISR API Boundary & Diagnostic Assertions

## Objective
Analyze why calling task-context APIs from interrupt handlers corrupts RTOS state, trace the Cortex-M3 active-exception assertion inside `portENTER_CRITICAL()`, and observe how `configASSERT()` traps execution.

## Prerequisites
- Lab 02: Synthetic TIM2 ISR handoff.
- Lab 04: Cortex-M3 NVIC/BASEPRI priority contracts.

## Estimated Time
- 45 minutes (MUST load).

## Architectural Principles

### 1. The Fundamental Context Boundary
FreeRTOS strictly partitions its API into two execution contexts:
| Feature | Task API (e.g. `xQueueSend`) | ISR API (e.g. `xQueueSendFromISR`) |
| :--- | :--- | :--- |
| **Execution Mode** | Thread mode (PSP) | Handler mode (MSP) |
| **Blocking / Timeout** | Supported (`xTicksToWait`) | **Forbidden** (must be non-blocking) |
| **Critical Section** | `portENTER_CRITICAL()` (increments `uxCriticalNesting`) | `portSET_INTERRUPT_MASK_FROM_ISR()` (saves & returns previous `BASEPRI`) |
| **Preemption Trigger** | Direct `vTaskSwitchContext()` via PendSV | Communicated via `*pxHigherPriorityTaskWoken` |

### 2. Failure Mechanism of Calling Task APIs from ISR
If a developer accidentally calls `xQueueSend(xQueue, &val, portMAX_DELAY)` inside `TIM2_IRQHandler()`:
1. **Critical-Nesting contract violation**: Task-context critical sections manipulate the port's `uxCriticalNesting` state. Calling them from Handler mode violates the port contract and can interfere with the interrupted task/kernel critical-section state.
2. **Illegal block attempt**: If the queue is full, `xQueueSend()` may follow a task-blocking path. Handler mode cannot participate in the task blocking/event-list protocol; using a task-context API here is unsupported.
3. **Diagnostic assertion on exercised paths**:
   In the pinned ARM_CM3 port (`portable/GCC/ARM_CM3/port.c`), `vPortEnterCritical()` contains:
   ```c
   configASSERT( ( portNVIC_INT_CTRL_REG & portVECTACTIVE_MASK ) == 0 );
   ```
   In Handler mode, `VECTACTIVE` is nonzero. When this check is reached at the first task-context critical nesting level, `configASSERT` catches the misuse. This is a diagnostic path, not a guarantee that every task-API-from-ISR misuse reaches the same assertion.

### 3. Non-Guaranteed HardFault Disclaimer
Notice: Calling a task API from an ISR does **not** generate a hardware HardFault by itself. The Cortex-M hardware does not forbid writing to registers from Handler mode. The failure is a logical OS software protocol violation that corrupts memory unless caught by `configASSERT`. Without assertions enabled, behavior is erratic and undefined.

## Lab Procedure
1. Inspect `vendor/freertos/portable/GCC/ARM_CM3/port.c` at `vPortEnterCritical()`:
   Observe the assertion checking `( portNVIC_INT_CTRL_REG & portVECTACTIVE_MASK ) == 0`.
2. Inspect `src/runtime_glue.c` to see how `vAssertCalled()` traps with `__disable_irq()` and `while(1)`.
3. In Fault fixture `f3` (`fundamentals/rtos/02-freertos-queue-isr-boundary/faults/f3`), inspect the defective code where `xQueueSend` is erroneously called inside `TIM2_IRQHandler`.

> **Status**: Source inspection and symbol contracts VERIFIED; GDB session trapping UNVERIFIED (Headless automated build).
