# P2-M02 Reviewer Hints & Pedagogical Guidance

> **Role**: Instructor / Reviewer Reference  
> **Audience**: Instructors evaluating learners or assisting stuck learners during lab progression.

---

## 1. Socratic Questioning Prompts

When learners are stuck during P2-M02 labs, use these graduated Socratic prompts:

### On MMIO and `volatile` Semantics (Lab 01)
1. "When you write `uint32_t val = TIM2->CR1;`, why doesn't GCC optimize away repeated reads in a loop?"
2. "Does `volatile` prevent the processor from buffering writes in its store buffer before they hit the peripheral bus?"
3. "Why does `ODR |= (1 << 2);` fail under interrupt preemption even though `ODR` is declared `volatile`?"

### On Clock Tree & APB Prescalers (Lab 02 & Fault 3)
1. "Look at the STM32F103 clock tree in RM0008 Figure 8. What is the maximum allowed frequency for APB1?"
2. "When APB1 prescaler is `/2` (dividing 72 MHz down to 36 MHz), what does the hardware do to the clock feeding TIM2/3/4?"
3. "If you calculate TIM2 prescaler assuming $f_{\text{input}} = 36\text{ MHz}$, will the timer run too fast or too slow?"
4. "Why must Flash wait states in `FLASH->ACR` be configured BEFORE switching SYSCLK to 72 MHz?"

### On Timer Interrupts & Flag Acknowledgment (Lab 03 & Fault 2)
1. "What hardware line does TIM2 assert when an update event occurs?"
2. "When the CPU enters `TIM2_IRQHandler`, does the hardware automatically clear bit 0 in `TIM2->SR`?"
3. "What happens as soon as the CPU executes `BX LR` to return from the ISR if `TIM2->SR[UIF]` is still 1?"
4. "Why do we execute `__DSB()` immediately after writing `TIM2->SR = ~TIM_SR_UIF;`?"

### On NVIC Priorities & Bit Shifts (Lab 04 & Fault 4)
1. "How many priority bits does STM32F103 physically implement in each NVIC priority register?"
2. "Which nibble of `NVIC->IP[x]` holds those implemented bits: the upper `[7:4]` or lower `[3:0]`?"
3. "If you write `NVIC->IP[28] = 6;`, what value does the hardware register actually read back?"
4. "Why does CMSIS provide `NVIC_SetPriority(IRQn, priority)` instead of direct array assignment?"

### On RMW Race Conditions & BSRR (Lab 05 & Fault 5)
1. "How many machine instructions are executed for `GPIOA->ODR ^= (1 << 1);`?"
2. "What happens if an ISR modifies pin 2 between the `LDR` and `STR` of pin 1 in Thread mode?"
3. "How does writing to `BSRR` avoid the `LDR` step completely?"

---

## 2. Common Student Traps & Misconceptions

| Misconception | Reality | How to Redirect |
|---|---|---|
| "`volatile` makes variable access thread-safe and atomic." | `volatile` only prevents compiler dead-store/load caching. It provides zero atomicity for read-modify-write sequences. | Show disassembly: `LDR`, `ORR`, `STR` are three distinct instructions. |
| "Timer clock is always equal to the APB bus clock." | On STM32F1, if APB prescaler != 1, timer clock is doubled ($\times 2$). TIM2 clock is 72 MHz, not 36 MHz. | Direct student to RM0008 Section 6.2 (Timer clock). |
| "Entering an ISR automatically clears the peripheral interrupt flag." | Hardware sets the NVIC active state, but the peripheral `SR` flag remains asserted until explicitly cleared by software. | Have student comment out the flag clear and observe the CPU trapped in the ISR. |
| "Logical priority 15 is higher priority than logical priority 0." | In Arm Cortex-M NVIC, 0 is the highest priority (most urgent) and 15 is the lowest. | Check PM0056 Section 4.3. |
| "Flash latency can be set after clock configuration." | If SYSCLK reaches 72 MHz while Flash latency is 0 WS, CPU prefetch immediately crashes on corrupted instruction bytes. | Emphasize chronological order: Flash latency -> Enable HSE -> Enable PLL -> Switch SYSCLK. |
