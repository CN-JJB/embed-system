# P2-M05 Challenge: ISR-to-Task Synchronization & Syscall Boundary Defense

> Mode: **AI-Free (Strict)**  
> Target Silicon: **STM32F103C8T6** (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM)  
> Submission Directory: `fundamentals/rtos/02-freertos-queue-isr-boundary/challenge/starter/`

---

## 1. Challenge Specification

You are tasked with engineering a robust, interrupt-driven synchronization pipeline between a hardware timer interrupt service routine (`TIM2_IRQHandler`) and a high-priority consumer task (`Task_Consumer`).

Your implementation must satisfy these non-negotiable architectural contracts:

1. **FreeRTOSConfig Syscall Boundary**:
   - `configPRIO_BITS` must be 4.
   - `configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY` must be 5.
   - `configMAX_SYSCALL_INTERRUPT_PRIORITY` must correctly bit-shift the library limit into the upper 4 bits (`0x50`).
2. **Cortex-M3 Priority Grouping**:
   - Establish `NVIC_SetPriorityGrouping(0)` so that all implemented priority bits are pre-emption priority bits.
3. **Interrupt Priority & Safety**:
   - Configure TIM2 interrupt with CMSIS logical priority 6 (encoded byte `0x60`), strictly within the safe syscall boundary.
   - `TIM2_IRQHandler()` must acknowledge the hardware interrupt flag (`TIM_SR_UIF`).
4. **Queue Allocation & Item Semantics**:
   - Create a queue of length 10 with item size `sizeof(uint32_t)`.
   - Consumer task must run at Priority 3 and block indefinitely via `xQueueReceive(queue, &rx_val, portMAX_DELAY)`.
5. **Interrupt Handoff & Deferred Context Switch**:
   - In `TIM2_IRQHandler()`, enqueue sequence numbers using `xQueueSendFromISR()`.
   - Explicitly handle queue-full conditions: if `xQueueSendFromISR()` returns `errQUEUE_FULL`, increment `g_isr_dropped_count`.
   - Propagate task preemption by invoking `portYIELD_FROM_ISR(xHigherPriorityTaskWoken)`.
   - Never call non-ISR task APIs (e.g. `xQueueSend()`) from inside the interrupt handler.
6. **Zero Memory Allocation Churn & Zero Libc Heap**:
   - No libc dynamic memory allocators (`malloc`, `calloc`, `realloc`, `free`).
   - Pure CMSIS registers; no HAL or CubeMX code.

---

## 2. Starter Files

Your submission consists of the three files in `starter/`:
- `FreeRTOSConfig.h`: Complete kernel interrupt boundaries and handler remapping.
- `queue_app.h`: Interface declarations and telemetry exports.
- `queue_app.c`: Queue creation, consumer task logic, and TIM2 configuration/ISR.

---

## 3. Verification

Run the automated validator to grade your submission:
```bash
bash fundamentals/rtos/02-freertos-queue-isr-boundary/challenge/verify_challenge.sh
```
The validator tests all 12 architectural contracts, compiles against the pinned FreeRTOS V11.3.0 kernel, and disassembles the generated binary.
