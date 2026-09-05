# P2-M05 Module Gate Solution & Diagnosis

## Candidate Fault Diagnosis

### Defect 1: Priority Threshold Violation in `NVIC_SetPriority`
- **Location**: `gate/gate_fault_firmware/src/main.c` line 85:
  ```c
  NVIC_SetPriority(TIM2_IRQn, 3);
  ```
- **Symptom**: Traps inside `vPortValidateInterruptPriority()` with assertion:
  ```c
  configASSERT( ucCurrentPriority >= ucMaxSysCallPriority );
  ```
- **Root Cause**: Logical priority 3 (encoded byte `0x30`) is higher urgency than `configMAX_SYSCALL_INTERRUPT_PRIORITY` (`0x50`). It is not masked during FreeRTOS critical sections, making calls to `xQueueSendFromISR` unsafe.
- **Fix**: Set `NVIC_SetPriority(TIM2_IRQn, 6)`.

### Defect 2: Polling Queue Receive with 0 Timeout
- **Location**: `gate/gate_fault_firmware/src/main.c` line 25:
  ```c
  if (xQueueReceive(s_telemetry_queue, &packet, 0) == pdPASS)
  ```
- **Symptom**: `prvTelemetryDispatchTask` runs at Priority 3 and constantly spins in a busy-wait loop, consuming 100% of CPU cycles and starving lower-priority tasks and Idle task.
- **Root Cause**: Polling with timeout 0 instead of blocking with `portMAX_DELAY`.
- **Fix**: Change timeout to `portMAX_DELAY`.

### Defect 3: Missing `portYIELD_FROM_ISR`
- **Location**: `gate/gate_fault_firmware/src/main.c` line 56:
  ```c
  (void)xHigherPriorityTaskWoken;
  ```
- **Symptom**: When `prvTelemetryDispatchTask` is unblocked by incoming data, no immediate PendSV exception is pended, causing dispatch latency up to 1 ms.
- **Fix**: Replace `(void)xHigherPriorityTaskWoken;` with `portYIELD_FROM_ISR(xHigherPriorityTaskWoken);`.

## Verification
Automated regression test:
```bash
bash fundamentals/rtos/02-freertos-queue-isr-boundary/reviewer/verify_gate_regression.sh
```
Proves that:
1. Unpatched binary is detected with all 3 defects.
2. Patched firmware compiles with 0 warnings.
3. Disassembly verifies `portYIELD_FROM_ISR` writes to `SCB->ICSR` (`0xE000ED04`).
4. Pristine state is restored after verification.
