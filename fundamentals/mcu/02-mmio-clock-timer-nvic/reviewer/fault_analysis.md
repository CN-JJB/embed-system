# P2-M02 Fault Analysis & Diagnostic Chains

This document details the complete hypothesis-driven diagnostic chains for all five deliberate fault fixtures in Module P2-M02.

---

## Fault 1: Unclocked Peripheral Access (`faults/fault1_clock_not_enabled/`)

- **Symptom**:
  The firmware initializes TIM2, but `g_tim2_ticks` never advances, PA1 never toggles, and reading `TIM2->CNT` in GDB always returns `0`.
- **Hypotheses**:
  1. TIM2 counter enable bit (`CEN`) in `TIM2->CR1` was not set.
  2. The peripheral bus clock for TIM2 is not enabled in `RCC->APB1ENR`.
  3. The NVIC interrupt for `TIM2_IRQn` is disabled or priority masked.
  4. Timer prescaler or auto-reload values are set to 0.
- **Evidence**:
  In GDB:
  ```gdb
  (gdb) print /x RCC->APB1ENR
  $1 = 0x0
  (gdb) print /x TIM2->CR1
  $2 = 0x0
  (gdb) set TIM2->CR1 = 1
  (gdb) print /x TIM2->CR1
  $3 = 0x0   <-- Register writes are silently ignored by unclocked silicon!
  ```
- **Root Cause**:
  In `timer_faulty.c`, `RCC->APB1ENR |= RCC_APB1ENR_TIM2EN;` was omitted. In STM32 microcontrollers, peripheral register logic is unpowered/unclocked by default to minimize power consumption. Accessing unclocked registers results in writes being silently discarded.
- **Minimal Fix**:
  Add clock gating enable in `tim2_init_1khz()` before accessing TIM2 registers:
  ```c
  RCC->APB1ENR |= RCC_APB1ENR_TIM2EN;
  ```
- **Regression**:
  Rebuild and check in GDB: `RCC->APB1ENR` bit 0 is set (`0x1`), and `TIM2->CR1` reads back non-zero.

---

## Fault 2: Interrupt Storm / Unacknowledged Flag (`faults/fault2_flag_not_cleared/`)

- **Symptom**:
  Target executes the first timer interrupt, and then permanently freezes. The main loop in `main()` stops executing, and the user LED or PA2 ceases toggling.
- **Hypotheses**:
  1. The main thread encountered a HardFault.
  2. The timer interrupt flag in `TIM2->SR` is not being acknowledged and cleared, causing the NVIC to immediately re-enter the ISR (Interrupt Storm).
  3. The watchdog timer triggered a reset.
  4. Global interrupts were disabled via `__disable_irq()`.
- **Evidence**:
  Halt target in GDB:
  ```gdb
  (gdb) continue
  ^C
  (gdb) bt
  #0  TIM2_IRQHandler () at timer_faulty.c:30
  (gdb) stepi
  ... CPU jumps back to TIM2_IRQHandler immediately upon BX LR!
  (gdb) print /x TIM2->SR
  $1 = 0x1   <-- UIF (Update Interrupt Flag) remains 1!
  ```
- **Root Cause**:
  In `timer_faulty.c`, `TIM2_IRQHandler()` failed to execute `TIM2->SR = ~TIM_SR_UIF;`. Entering an ISR clears the NVIC pending latch, but does not clear the peripheral interrupt request. The asserted request line immediately re-latches the interrupt as soon as the CPU exits to Thread mode.
- **Minimal Fix**:
  Acknowledge the flag in `TIM2_IRQHandler()`:
  ```c
  TIM2->SR = ~TIM_SR_UIF;
  __DSB();
  ```
- **Regression**:
  Recompile and verify in GDB that `main()` resumes execution and `g_tim2_ticks` increments monotonically at 1000 Hz.

---

## Fault 3: Timer Clock Doubler Miscalculation (`faults/fault3_timer_clock_math/`)

- **Symptom**:
  Timer interrupt fires at twice the expected frequency (2000 Hz instead of 1000 Hz; period is 500 us instead of 1.0 ms).
- **Hypotheses**:
  1. External HSE crystal is 16 MHz instead of 8 MHz.
  2. PLL multiplier was configured to 18 instead of 9.
  3. Prescaler calculation assumed timer input clock equals APB1 peripheral clock (36 MHz), missing the RM0008 timer clock doubler ($\times 2$).
  4. Auto-reload register was set to 499 instead of 999.
- **Evidence**:
  Measure PA1 pin on oscilloscope or logic analyzer: period is 500 us (2.0 kHz).
  Check GDB:
  ```gdb
  (gdb) print TIM2->PSC
  $1 = 35    <-- PSC = 35 means counter clock = 72 MHz / 36 = 2 MHz!
  (gdb) print TIM2->ARR
  $2 = 999
  ```
- **Root Cause**:
  RM0008 Section 6.2 states: "The timer clock frequencies are automatically fixed by hardware. If the APB prescaler is 1, the timer clock frequencies are set to the same value as that of the APB domain. Otherwise, they are set to twice ($\times 2$) the value of the APB domain." Because APB1 prescaler is `/2` (36 MHz), the timer clock is $36 \times 2 = 72\text{ MHz}$. Software author erroneously assumed 36 MHz and derived `PSC = 35`.
- **Minimal Fix**:
  Use 72 MHz in prescaler derivation:
  ```c
  uint32_t psc_val = (timclk_hz / 1000000U) - 1U; /* 72 MHz / 1 MHz - 1 = 71 */
  ```
- **Regression**:
  Verify with `bash scripts/verify_m02.sh` that timer arithmetic produces exactly 1000 Hz.

---

## Fault 4: NVIC Priority Encoding Error (`faults/fault4_nvic_priority_error/`)

- **Symptom**:
  An interrupt intended to be low urgency (logical priority 6) blocks or preempts higher urgency interrupts, or exhibits unexpected priority behavior.
- **Hypotheses**:
  1. NVIC grouping configuration in `SCB->AIRCR` was corrupted.
  2. The priority byte was written with an unshifted value, writing into unimplemented low bits of `NVIC->IP[x]`.
  3. Priority inversion occurred at the RTOS level.
- **Evidence**:
  In GDB:
  ```gdb
  (gdb) print /x NVIC->IP[TIM2_IRQn]
  $1 = 0x0   <-- Value reads as 0x00 (Highest preemption priority!)
  ```
- **Root Cause**:
  In `timer_faulty.c`, the author wrote `NVIC->IP[TIM2_IRQn] = 6;`. On STM32F103, only the upper 4 bits (`[7:4]`) are physically implemented. The lower 4 bits (`[3:0]`) are read-as-zero / write-ignored. Writing `0x06` writes `0` to bits `[7:4]`, setting the priority to `0x00` (highest priority).
- **Minimal Fix**:
  Use CMSIS API which handles the required shift `(priority << (8 - __NVIC_PRIO_BITS))`:
  ```c
  NVIC_SetPriority(TIM2_IRQn, 6);
  ```
- **Regression**:
  Inspect `NVIC->IP[TIM2_IRQn]` in GDB: confirms it contains `0x60` (decimal 96), corresponding to logical priority 6.

---

## Fault 5: Read-Modify-Write Shared Register Race (`faults/fault5_rmw_hazard/`)

- **Symptom**:
  When the system is under interrupt load, output pulses on PA2 are intermittently missing or corrupted, or PA1 toggling is delayed.
- **Hypotheses**:
  1. GPIO pin capacitance or slew rate limits are causing edge deformation.
  2. Non-atomic read-modify-write on `GPIOA->ODR` in Thread mode is preempted by `TIM2_IRQHandler`, corrupting the register state.
  3. Compiler optimization reordered the pin toggle statements.
- **Evidence**:
  Disassemble `main()`:
  ```assembly
  ldr r1, [r0, #12]   ; Read GPIOA->ODR
  orr r1, r1, #4      ; Set bit 2
  str r1, [r0, #12]   ; Write back
  ```
  If `TIM2_IRQHandler` fires between `ldr` and `str` and modifies bit 1 (`GPIOA->ODR ^= 2`), that modification is overwritten when `main()` executes its `str`!
- **Root Cause**:
  `GPIOA->ODR` is a shared hardware register. Bitwise operators `|=` and `&=` in C require a 3-instruction load-modify-store sequence. Preemption during this sequence causes a classic race condition.
- **Minimal Fix**:
  Replace `ODR` access with atomic `BSRR` / `BRR` writes:
  ```c
  GPIOA->BSRR = GPIO_BSRR_BS2;  /* Atomic set */
  GPIOA->BRR  = GPIO_BRR_BR2;   /* Atomic reset */
  ```
- **Regression**:
  Verify assembly: `BSRR` compiles to a single `STR` instruction without any preceding `LDR`, making it mathematically immune to preemption race hazards.
