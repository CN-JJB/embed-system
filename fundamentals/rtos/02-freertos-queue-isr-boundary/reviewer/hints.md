# P2-M05 Socratic Hint Ladder

> For guidance during labs, faults, and challenge without revealing code.

---

## Lab 02 & 03: Queue Handoff & Yielding
- **Hint 1**: How does the kernel know that an interrupt has unblocked a task whose priority is higher than the currently running task?
- **Hint 2**: Trace `xTaskRemoveFromEventList()` in `tasks.c`. What is the condition under which `pdTRUE` is returned?
- **Hint 3**: When `portYIELD_FROM_ISR()` is called, does it immediately switch the context inside the ISR, or does it set a hardware exception pending bit?

---

## Lab 04 & Fault `f1`: NVIC Priority Boundaries
- **Hint 1**: On Cortex-M3, is priority 0 higher urgency or lower urgency than priority 5?
- **Hint 2**: When `NVIC_SetPriority(IRQn, prio)` is called, how does it translate `prio` into the hardware register byte?
- **Hint 3**: What value does FreeRTOS write to `BASEPRI` during a critical section? What happens to interrupts with priority numbers smaller than that value?

---

## Lab 05 & Fault `f3`: Task APIs in ISR Context
- **Hint 1**: Why does `portENTER_CRITICAL()` inspect `SCB->ICSR` bits [8:0] (`VECTACTIVE`)?
- **Hint 2**: Can an interrupt handler block and wait for timeout? If `xQueueSend()` blocks, what happens to the interrupt execution frame on Cortex-M?

---

## Fault `f4` & Gate: Missing Yield
- **Hint 1**: The task is unblocked and placed on the Ready list, but why does it wait for the next SysTick to run?
- **Hint 2**: Look at the disassembly of `TIM2_IRQHandler`. Does it write to `0xE000ED04`?
