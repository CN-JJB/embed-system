# P2-M05 Fault Analysis: Comprehensive Learner Diagnostics

## Fixture `f1`: Invalid ISR Priority for FreeRTOS Syscall

### Scenario-Reported Symptom & Behavior
Microcontroller boots, runs `main()`, initializes peripherals, and calls `vTaskStartScheduler()`. Within 10 ms (at the first TIM2 interrupt), the system enters `vAssertCalled()` from `vPortValidateInterruptPriority()`.

### Hypothesis Tree
1. **H1**: TIM2 interrupt was not enabled in RCC or GPIO was not configured.
2. **H2**: TIM2 was configured with CMSIS logical priority 2, shifting to encoded byte `0x20`, which is higher urgency than `configMAX_SYSCALL_INTERRUPT_PRIORITY` (`0x50`).
3. **H3**: Priority grouping was not configured.
4. **H4**: Task stack underflowed during interrupt entry.

### Evidence
Inspecting `faults/f1/timer_f1.c`:
```c
NVIC_SetPriority(TIM2_IRQn, 2);
```
Logical priority 2 shifts to hardware byte `0x20`. In `vPortValidateInterruptPriority()`:
```c
ucCurrentPriority = pcInterruptPriorityRegisters[ ulCurrentInterrupt ];
configASSERT( ucCurrentPriority >= ucMaxSysCallPriority );
```
Since `0x20 < 0x50`, the assertion trips.

### Root Cause
An interrupt that calls FreeRTOS APIs was assigned logical priority 2, placing it above the `BASEPRI` masking threshold.

### Minimal Fix
Change `NVIC_SetPriority(TIM2_IRQn, 2)` to `NVIC_SetPriority(TIM2_IRQn, 6)`.

### Regression
Recompile and verify that `vPortValidateInterruptPriority()` passes without triggering assertion.

---

## Fixture `f2`: Priority Grouping Misconfiguration

### Scenario-Reported Symptom & Behavior
CPU hangs inside `vAssertCalled()` upon the first call to `xQueueSendFromISR()`, even though `NVIC_SetPriority(TIM2_IRQn, 6)` was configured.

### Hypothesis Tree
1. **H1**: Timer clock rate is incorrect.
2. **H2**: Priority grouping in `SCB->AIRCR` was set to an unsupported value with subpriority bits.
3. **H3**: Queue handle was `NULL`.

### Evidence
Inspecting `faults/f2/main_f2.c`:
```c
NVIC_SetPriorityGrouping(5);
```
In `vPortValidateInterruptPriority()`:
```c
configASSERT( ( portAIRCR_REG & portPRIORITY_GROUP_MASK ) <= ulMaxPRIGROUPValue );
```
Setting grouping to 5 splits the 4 priority bits into 2 bits preemption and 2 bits subpriority, violating the port contract.

### Root Cause
`NVIC_SetPriorityGrouping(5)` leaves fewer preemption bits than expected by `vPortValidateInterruptPriority()`.

### Minimal Fix
Set `NVIC_SetPriorityGrouping(0)` so that all 4 bits are preemption priority bits.

---

## Fixture `f3`: Calling Task-Context API from ISR Context

### Scenario-Reported Symptom & Behavior
Firmware traps inside `vAssertCalled()` on the first timer interrupt with call stack pointing to `vPortEnterCritical()`.

### Hypothesis Tree
1. **H1**: Heap exhaustion occurred during queue transmission.
2. **H2**: Task API `xQueueSend()` was called from inside `TIM2_IRQHandler()`, which invoked `portENTER_CRITICAL()`.
3. **H3**: Interrupt flag was not acknowledged.

### Evidence
Inspecting `faults/f3/timer_f3.c`:
```c
xQueueSend(g_sample_queue, (const void *)&s_seq, 0);
```
`vPortEnterCritical()` contains:
```c
configASSERT( ( portNVIC_INT_CTRL_REG & portVECTACTIVE_MASK ) == 0 );
```
Inside an ISR, `VECTACTIVE` is non-zero (Vector 44 for TIM2), triggering the assertion.

### Root Cause
A task-context API (`xQueueSend`) that assumes Thread mode was called from Handler mode.

### Minimal Fix
Replace `xQueueSend()` with `xQueueSendFromISR(g_sample_queue, &s_seq, &xHigherPriorityTaskWoken)`.

---

## Fixture `f4`: Missing Yield Request in ISR

### Scenario-Reported Symptom & Behavior
Firmware runs without assertions or crashes, but consumer task unblocks with up to 1 ms latency and high timing jitter.

### Hypothesis Tree
1. **H1**: Consumer task was configured with lower priority than Idle task.
2. **H2**: `portYIELD_FROM_ISR()` was omitted, so PendSV was never asserted from the ISR.
3. **H3**: Hardware timer period was set to 1 second instead of 10 ms.

### Evidence
In `faults/f4/timer_f4.c`, `portYIELD_FROM_ISR(xHigherPriorityTaskWoken)` is omitted. The disassembly confirms that `SCB->ICSR` (`0xE000ED04`) is never written to trigger PendSV.

### Root Cause
Without `portYIELD_FROM_ISR()`, preemption is delayed until the next SysTick interrupt forces a context switch.

### Minimal Fix
Add `portYIELD_FROM_ISR(xHigherPriorityTaskWoken)` at the exit of `TIM2_IRQHandler()`.

---

## Fixture `f5`: Queue Item Size Mismatch

### Scenario-Reported Symptom & Behavior
The system runs without crashing, but sequence numbers received by `Task_Consumer` are corrupted or truncated, causing `g_consumer_sequence_errors` to rapidly increase.

### Hypothesis Tree
1. **H1**: Memory corruption caused by stack overflow.
2. **H2**: Queue was initialized with item size `sizeof(uint8_t)` while producer writes `uint32_t`.
3. **H3**: Sequence counter variable overflowed.

### Evidence
In `faults/f5/queue_app_f5.c`:
```c
g_sample_queue = xQueueCreate(QUEUE_APP_LENGTH, sizeof(uint8_t));
```
The queue only stores 1 byte per item. When `xQueueReceive` reads 4 bytes into `&rx_val`, the upper 3 bytes are either zero or uninitialized.

### Root Cause
`xQueueCreate` used item size `sizeof(uint8_t)` instead of `sizeof(uint32_t)`.

### Minimal Fix
Change `sizeof(uint8_t)` to `sizeof(uint32_t)` in `xQueueCreate()`.
