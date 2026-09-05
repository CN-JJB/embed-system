# P2-M02 Fault Analysis & Diagnostic Chains

This document details the complete hypothesis-driven diagnostic chains for all five deliberate fault fixtures in Module P2-M02.

---

## Fixture F1: Unclocked Peripheral Access (`faults/f1/`)

- **Symptom**:
  The firmware initializes TIM2, but `g_tim2_ticks` never advances, PA1 never toggles, and reading `TIM2->CNT` always returns `0`.
- **Hypotheses**:
  1. TIM2 counter enable bit (`CEN`) in `TIM2->CR1` was not set.
  2. The peripheral bus clock for TIM2 is not enabled in `RCC->APB1ENR`.
  3. The NVIC interrupt for `TIM2_IRQn` is disabled or priority masked.
  4. Timer prescaler or auto-reload values are set to 0.
- **Evidence**:
  Static binary audit (VERIFIED on host): Disassembly shows `RCC->APB1ENR` is never accessed in `tim2_init_1khz()`.
  
  Target GDB Inspection (Expected / Illustrative; hardware run UNVERIFIED):
  ```text
  (gdb) print /x RCC->APB1ENR
  $1 = 0x0
  (gdb) print /x TIM2->CR1
  $2 = 0x0
  (gdb) set TIM2->CR1 = 1
  (gdb) print /x TIM2->CR1
  $3 = 0x0   <-- Register writes are silently ignored by unclocked silicon!
  ```
- **Root Cause**:
  In `timer_faulty.c`, `RCC->APB1ENR |= RCC_APB1ENR_TIM2EN;` was omitted. In STM32 microcontrollers, peripheral register logic is unpowered/unclocked by default to minimize power consumption. Accessing unclocked registers results in writes being silently discarded by hardware.
- **Minimal Fix**:
  Add clock gating enable in `tim2_init_1khz()` before accessing TIM2 registers:
  ```c
  RCC->APB1ENR |= RCC_APB1ENR_TIM2EN;
  ```
- **Regression**:
  Rebuild and check in GDB: `RCC->APB1ENR` bit 0 is set (`0x1`), and `TIM2->CR1` reads back non-zero.

---

## Fixture F2: Interrupt Storm / Unacknowledged Flag (`faults/f2/`)

- **Symptom**:
  Target executes the first timer interrupt, and then permanently freezes. The main loop in `main()` stops executing, and Thread mode is completely starved.
- **Hypotheses**:
  1. The processor encountered a HardFault or lockup exception.
  2. The timer interrupt flag in `TIM2->SR` is not being acknowledged and cleared, causing the NVIC to immediately re-enter the ISR (Interrupt Storm).
  3. The watchdog timer triggered a reset.
  4. Global interrupts were disabled via `__disable_irq()`.
- **Evidence**:
  Static binary audit (VERIFIED on host): `TIM2_IRQHandler` disassembly contains no store (`STR`) to address `TIM2_BASE + 0x10` (`TIM2->SR`).

  Target GDB Inspection (Expected / Illustrative; hardware run UNVERIFIED):
  ```text
  (gdb) continue
  ^C
  (gdb) bt
  #0  TIM2_IRQHandler () at timer_faulty.c:28
  (gdb) stepi
  ... CPU jumps back to TIM2_IRQHandler immediately upon BX LR!
  (gdb) print /x TIM2->SR
  $1 = 0x1   <-- UIF (Update Interrupt Flag) remains 1!
  ```
- **Root Cause**:
  In `timer_faulty.c`, `TIM2_IRQHandler()` failed to execute `TIM2->SR = ~TIM_SR_UIF;`. Entering an ISR clears the NVIC pending latch, but does not clear the peripheral interrupt request in hardware. The continuously asserted peripheral line immediately causes the NVIC to re-pend the exception upon return (`BX LR`), starving Thread mode.
- **Minimal Fix**:
  Acknowledge the flag in `TIM2_IRQHandler()`:
  ```c
  TIM2->SR = ~TIM_SR_UIF;
  __DSB();
  ```
- **Regression**:
  Recompile and verify in GDB that `main()` resumes execution and `g_tim2_ticks` increments monotonically.

---

## Fixture F3: Timer Clock Doubler Miscalculation (`faults/f3/`)

- **Symptom**:
  Timer interrupt event rate occurs at twice the expected rate: 2000 events/s instead of 1000 events/s.
  Because PA1 is toggled once per ISR:
  - Expected toggle rate: 1000 toggles/s $\to$ 500 Hz square wave (2.0 ms period: 1.0 ms HIGH, 1.0 ms LOW).
  - Observed faulty toggle rate: 2000 toggles/s $\to$ 1000 Hz square wave (1.0 ms period: 500 us HIGH, 500 us LOW).
- **Hypotheses**:
  1. External HSE crystal is 16 MHz instead of 8 MHz.
  2. PLL multiplier was configured to 18 instead of 9.
  3. Prescaler calculation assumed timer input clock equals APB1 peripheral clock (36 MHz), missing the RM0008 timer clock doubler ($\times 2$).
  4. Auto-reload register was set to 499 instead of 999.
- **Evidence**:
  Static binary audit (VERIFIED on host):
  Disassembly of `tim2_init_1khz` in `f3` shows:
  ```text
  TIM2->PSC is loaded with 35 (0x23).
  ```
  Arithmetic derivation:
  $$f_{\text{counter}} = \frac{72\text{ MHz}}{35 + 1} = 2.0\text{ MHz}$$
  $$f_{\text{event}} = \frac{2.0\text{ MHz}}{999 + 1} = 2000\text{ Hz (2000 events/s)}$$
  Each update event executes `gpio_toggle_pa1_atomic()`.
  Two events form one complete square wave:
  $$f_{\text{square\_wave}} = \frac{2000}{2} = 1000\text{ Hz (1.0 ms square-wave period, 500 }\mu\text{s interval)}$$
- **Root Cause**:
  RM0008 Section 6.2 states: "The timer clock frequencies are automatically fixed by hardware. If the APB prescaler is 1, the timer clock frequencies are set to the same value as that of the APB domain. Otherwise, they are set to twice ($\times 2$) the value of the APB domain." Because APB1 prescaler is `/2` (36 MHz), the timer clock is $36 \times 2 = 72\text{ MHz}$. Software author erroneously assumed 36 MHz and derived `PSC = 35`.
- **Minimal Fix**:
  Use 72 MHz in prescaler derivation:
  ```c
  uint32_t psc_val = (timclk_hz / 1000000U) - 1U; /* 72 MHz / 1 MHz - 1 = 71 */
  ```
- **Regression**:
  Verify with `bash scripts/verify_m02.sh` that timer arithmetic produces exactly 1000 Hz event rate (500 Hz square wave).

---

## Fixture F4: Interrupt Priority Register Encoding (`faults/f4/`)

- **Symptom**:
  Software intends to set `TIM2_IRQn` to logical priority 6, but inspecting the hardware register `NVIC->IP[TIM2_IRQn]` in GDB or memory reveals `0x00`.
- **Hypotheses**:
  1. The NVIC priority register was cleared by an unhandled reset.
  2. The priority byte was written with an unshifted value, landing in the unimplemented lower 4 bits of the hardware register.
  3. An incorrect IRQ number index was used in array subscripting.
- **Evidence**:
  Static binary audit (VERIFIED on host):
  Disassembly of `tim2_init_1khz` in `f4` shows:
  ```assembly
  movs r2, #6
  strb r2, [r1, #28]   ; Stores raw 0x06 into NVIC->IP[28]
  ```
  Architectural analysis (PM0056 Section 4.3):
  STM32F103 physically implements only 4 priority bits (`__NVIC_PRIO_BITS = 4`), which reside in bits `[7:4]` of each byte in `NVIC->IP[x]`. Bits `[3:0]` are read-as-zero / write-ignored.
  When `0x06` (`0b00000110`) is written:
  - Bits `[7:4]` receive `0b0000` (`0x00`);
  - Bits `[3:0]` receive `0b0110` (ignored by silicon).
  Therefore, the register reads back as `0x00` (which hardware interprets as Priority 0, highest urgency!).
- **Root Cause**:
  In `timer_faulty.c`, the author wrote `NVIC->IP[TIM2_IRQn] = 6;` directly instead of shifting the logical priority by `8 - __NVIC_PRIO_BITS` (i.e. `6 << 4 = 0x60`).
- **Minimal Fix**:
  Use CMSIS standard macro which automatically encodes the bit shift:
  ```c
  NVIC_SetPriority(TIM2_IRQn, 6);
  ```
- **Regression**:
  Disassemble the corrected function: confirms `0x60` is written to `NVIC->IP[28]`.

---

## Fixture F5: Read-Modify-Write Shared Register Race (`faults/f5/`)

- **Symptom**:
  When the firmware runs with concurrent execution between Thread mode and the periodic timer interrupt, output pulses on shared GPIO pins exhibit missing edges or sporadic glitches.
- **Hypotheses**:
  1. GPIO pin capacitance or slew rate limits are causing edge deformation.
  2. Non-atomic read-modify-write on `GPIOA->ODR` in Thread mode is preempted by `TIM2_IRQHandler`, corrupting the register state.
  3. Compiler optimization reordered the pin toggle statements.
- **Evidence**:
  Static binary audit (VERIFIED on host):
  Disassembly of `main_faulty.c` shows:
  ```assembly
  ldr r1, [r0, #12]   ; Read GPIOA->ODR (offset 0x0C)
  orr r1, r1, #4      ; Modify bit 2 in core register
  str r1, [r0, #12]   ; Write back to GPIOA->ODR
  ```
  Disassembly of `timer_rmw.c` (`TIM2_IRQHandler`) shows:
  ```assembly
  ldr r1, [r0, #12]   ; Read GPIOA->ODR in ISR
  eor r1, r1, #2      ; Toggle bit 1
  str r1, [r0, #12]   ; Write back to GPIOA->ODR
  ```
  If an interrupt occurs between the `ldr` and `str` in Thread mode, the ISR's modification of bit 1 is completely erased when Thread mode executes its pending `str`!
- **Root Cause**:
  `GPIOA->ODR` is a shared hardware register accessed across multiple execution contexts (Thread mode and Handler mode). Standard C bitwise operators (`|=`, `&=`, `^=`) compile to multi-instruction read-modify-write sequences (`LDR/ORR/STR`). Preemption during this sequence causes a classic race condition.
- **Minimal Fix**:
  Replace `ODR` bitwise access with atomic `BSRR` / `BRR` writes:
  ```c
  GPIOA->BSRR = GPIO_BSRR_BS2;  /* Atomic set */
  GPIOA->BRR  = GPIO_BRR_BR2;   /* Atomic reset */
  ```
- **Regression**:
  Disassembly confirms `BSRR` compiles to a single `STR` without any preceding `LDR`, making the bus operation mathematically atomic and immune to preemption race hazards.
