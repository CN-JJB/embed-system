# Lab 02: Synthetic TIM2 ISR to Task Queue Handoff

## Objective
Implement a deferred interrupt processing pipeline using a periodic hardware timer (TIM2) at 100 Hz, enqueueing sequence numbers via `xQueueSendFromISR()`, and waking a consumer task (`Task_Consumer`) blocked on `xQueueReceive()`.

## Prerequisites
- P2-M02: Hardware timers, prescaler/ARR arithmetic, and interrupt flags.
- Lab 01: FreeRTOS queue structure and copy semantics.

## Estimated Time
- 45 minutes (MUST load).

## Architectural Principles

### 1. Timer Setup and Interrupt Frequency
On STM32F103, TIM2 is connected to the APB1 peripheral bus:
- With APB1 prescaler set to 2 (`RCC_CFGR_PPRE1_2`), the APB1 clock is 36 MHz (under 72 MHz SYSCLK).
- Hardware clock-doubling logic provides $2 \times 36\text{ MHz} = 72\text{ MHz}$ to TIM2.
- Configuring:
  $$\text{PSC} = \frac{f_{\text{TIM}}}{10,000} - 1 = \frac{72,000,000}{10,000} - 1 = 7199$$
  creates a 10 kHz base timer clock ($0.1\text{ ms}$ tick).
- Auto-reload for 100 Hz ($10\text{ ms}$ period):
  $$\text{ARR} = \frac{10,000}{100} - 1 = 99$$

### 2. The ISR Flag Acknowledgment Contract
Hardware sets `TIM2->SR & TIM_SR_UIF` when the counter reaches `ARR`.
Inside `TIM2_IRQHandler()`:
```c
TIM2->SR = (uint16_t)(~TIM_SR_UIF);
__DSB();
```
Clearing the flag immediately is mandatory. If omitted, the interrupt request remains asserted at the NVIC input, causing an immediate re-entry (interrupt storm) as soon as the ISR returns.

### 3. Enqueuing from Interrupt Context
`xQueueSendFromISR()` must be used instead of `xQueueSend()`:
- It never blocks; `xTicksToWait` is absent.
- It operates inside a critical section that masks interrupts via `BASEPRI` (`portSET_INTERRUPT_MASK_FROM_ISR()`).
- It takes a pointer to `BaseType_t xHigherPriorityTaskWoken`.

## Lab Procedure
1. Inspect `src/timer.c` and verify `timer2_init(100)` sets `PSC = 7199` and `ARR = 99`.
2. Inspect `TIM2_IRQHandler`: verify `xQueueSendFromISR()` is called with `&xHigherPriorityTaskWoken`.
3. In `src/queue_app.c`, inspect `prvConsumerTask()`:
   - Priority is set to 3.
   - It blocks on `xQueueReceive(g_sample_queue, &rx_val, portMAX_DELAY)`.
   - It verifies that received `rx_val` matches `expected_seq`.
4. Compile and verify static ELF structure:
   ```bash
   make -C fundamentals/rtos/02-freertos-queue-isr-boundary check
   ```

> **Observation Disclosure**: Static symbols and code contracts VERIFIED; logic analyzer waveform of PA1 falling to PA2 rising is UNVERIFIED (Headless automated build).
