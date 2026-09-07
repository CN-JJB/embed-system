# Phase 2 Final Gate: Detailed Reviewer Scoring Anchors

> **CONFIDENTIAL: REVIEWER REFERENCE MATERIALS — DO NOT DISTRIBUTE TO LEARNERS**

This document establishes concrete, point-by-point scoring anchors for each of the four Parts of the Phase 2 Final Gate assessment. Total available: **100.0 points**.

---

## Part A: Bare-Metal Startup & Linker Reasoning (25.0 Points Max, Floor: 15.0)

### Dimension A.1: Startup & Linker Mental Model (5.0 pts)
* **5.0 pts:** Accurately annotates all 7 startup phases (`MSP from vector 0`, `Thumb Reset_Handler entry`, `SystemInit under pre-.data/.bss invariant`, `.data LMA->VMA copy`, `.bss zeroing`, `__libc_init_array constructor dispatch`, and `main entry`). Explains that `SystemInit` cannot access writable static C globals.
* **3.0 pts:** Minor omissions in startup sequence (e.g. omits `__libc_init_array` or misstates `SystemInit` pre-runtime invariant).
* **0.0 pts:** Fundamental confusion regarding vector table loading, Thumb bit, or memory initialization order.

### Dimension A.2: ELF / Symbol / Map Evidence (5.0 pts)
* **5.0 pts:** Provides verbatim output from `arm-none-eabi-readelf -S` showing `.init_array` has size 0, and `nm` output showing constructor symbol is missing. Correctly identifies that `--gc-sections` discarded the section.
* **3.0 pts:** Identifies that the constructor didn't run, but evidence lacks verbatim tool outputs or map line numbers.
* **0.0 pts:** Fabricated evidence, or no Binutils inspection performed.

### Dimension A.3: Root Cause Reasoning (5.0 pts)
* **5.0 pts:** Explicitly articulates that because `system_peripheral_preinit` is only referenced via function pointer in the initialization table, the GNU linker's garbage collector discards the input section unless protected with `KEEP()`.
* **3.0 pts:** States that `.init_array` was stripped, but does not explain why `--gc-sections` treated it as unused.
* **0.0 pts:** Guesses unrelated causes (e.g. clock failure, wrong optimization level).

### Dimension A.4: Minimal Principled Correction (5.0 pts)
* **5.0 pts:** Corrects `linker/stm32f103c8tx_flash.ld` by adding `KEEP (*(.init_array*))` and `KEEP (*(SORT(.init_array.*)))`. Does not introduce unneeded changes or remove `-Wl,--gc-sections`.
* **2.5 pts:** Disables `--gc-sections` globally in Makefile rather than fixing the linker script.
* **0.0 pts:** Fails to repair the linker script.

### Dimension A.5: Automated Regression Proof (5.0 pts)
* **5.0 pts:** Provides verbatim output of `make check` passing, with `readelf -S` showing non-zero `.init_array` size (e.g. 4 bytes) and `nm` confirming symbol retention.
* **0.0 pts:** No regression test output provided.

---

## Part B: Peripheral Register & DMA Data-Path Diagnosis (25.0 Points Max, Floor: 15.0)

### Dimension B.1: Clock Tree & Trigger Rate Calculation (5.0 pts)
* **5.0 pts:** Correctly calculates:
  - TIM3 TRGO: $f_{\text{TRGO}} = \frac{72\text{ MHz}}{(71+1) \times (99+1)} = 10.0\text{ kHz}$ (100 µs interval).
  - ADCCLK: $f_{\text{ADCCLK}} = \frac{72\text{ MHz}}{6} = 12\text{ MHz} \le 14\text{ MHz}$.
  - ADC Conversion: $55.5 + 12.5 = 68.0\text{ cycles} = 5.67\text{ \mu s}$.
* **3.0 pts:** Minor arithmetic slip in prescalers, but formulas and 14 MHz constraint are correctly understood.
* **0.0 pts:** Inability to calculate timer or ADC clock frequencies from register values.

### Dimension B.2: Trigger / ADC / DMA Route Diagnosis (5.0 pts)
* **5.0 pts:** Accurately maps the autonomous trigger chain from `TIM3->CR2` (`MMS=010`), `ADC1->CR2` (`EXTSEL=100`, `EXTTRIG=1`, `DMA=1`), to `DMA1_Channel1->CPAR` / `CMAR`.
* **3.0 pts:** Confuses ADC software start with external hardware timer triggering.
* **0.0 pts:** Fails to trace peripheral data-path connection.

### Dimension B.3: Buffer & Interrupt Lifecycle Reasoning (5.0 pts)
* **5.0 pts:** Explains why Half-Transfer and Transfer-Complete interrupts continue to fire even when `MINC = 0` (because DMA transfer counter `CNDTR` decrements regardless of address increment). Identifies that `g_adc_buffer[0]` is overwritten 128 times per cycle.
* **3.0 pts:** Identifies that the buffer is unpopulated, but does not explain why interrupts fired.
* **0.0 pts:** Claims DMA stopped running entirely.

### Dimension B.4: Observable Evidence & Non-Proof (5.0 pts)
* **5.0 pts:** Accurately cites register bit values from `register_dump.txt` (`CCR = 0x2527`, bit 7 = 0) and buffer dump. Formulates clear Non-Proof statement: *"Static register verification does not prove analog input voltages were accurate or conversions were noise-free."*
* **3.0 pts:** Register citation present, but lacks Non-Proof boundary.
* **0.0 pts:** Claims live hardware execution from pre-recorded static fixtures.

### Dimension B.5: Minimal Fix & Regression Verification (5.0 pts)
* **5.0 pts:** Adds `DMA_CCR_MINC` to `DMA1_Channel1->CCR` in `src/dma.c`. Provides verbatim output of `make check` passing.
* **0.0 pts:** Fails to enable `MINC`.

---

## Part C: FreeRTOS Scheduling & Context Switch Mechanics (25.0 Points Max, Floor: 15.0)

### Dimension C.1: Cortex-M3 Exception & Stack Frame Model (5.0 pts)
* **5.0 pts:** Identifies Handler mode uses MSP (`0x20004ff8`); Thread mode task uses PSP (`0x20001210`). Correctly derives addresses and contents of the 8-word hardware frame (`r0-r3, r12, lr, pc, xpsr`) on PSP. Explains `EXC_RETURN = 0xFFFFFFFD` (return to Thread mode using PSP).
* **3.0 pts:** Confuses MSP and PSP roles, or miscalculates hardware stack frame offset.
* **0.0 pts:** Cannot explain Cortex-M3 exception stacking.

### Dimension C.2: PendSV Assembly & TCB Pointer Reasoning (5.0 pts)
* **5.0 pts:** Traces `xPortPendSVHandler` software push (`stmdb r0!, {r4-r11}`) saving 32 bytes on PSP. Calculates new `pxCurrentTCB->pxTopOfStack = 0x20001210 - 0x20 = 0x200011F0`. Explains how `pxCurrentTCB` is swapped.
* **3.0 pts:** Understands software stacking, but miscalculates the resulting stack pointer address.
* **0.0 pts:** Unfamiliar with Cortex-M3 context switch assembly.

### Dimension C.3: NVIC Priority vs BASEPRI Safety Audit (5.0 pts)
* **5.0 pts:** Decodes `NVIC->IP[EXTI0_IRQn] = 0x40` to logical priority 4 (`0x40 >> 4`). Explains that in Cortex-M3 lower numbers indicate higher urgency, so priority 4 is higher urgency than `configMAX_SYSCALL_INTERRUPT_PRIORITY` (`0x50` / logical 5). Explains that `BASEPRI = 0x50` fails to mask priority `0x40`, violating the FreeRTOS API critical section boundary.
* **3.0 pts:** Identifies that priority 4 is invalid, but confuses CMSIS logical priority with hardware byte encoding.
* **0.0 pts:** Claims priority 4 is lower priority than 5 because $4 < 5$.

### Dimension C.4: Evidence Interpretation & Non-Proof (5.0 pts)
* **5.0 pts:** Provides disciplined interpretation of GDB trace and explains Non-Proof: *"A single valid breakpoint trace does not prove the system is free from priority inversion or deadlock under heavy external interrupt load."*
* **3.0 pts:** Reasonable interpretation, but weak Non-Proof limits.
* **0.0 pts:** No evidence analysis.

### Dimension C.5: Priority Repair & Calculation Proof (5.0 pts)
* **5.0 pts:** Modifies `src/interrupt_config.c` to assign logical priority $\ge 5$ (e.g. 5, 6, or 7). Provides `make check` passing proof.
* **0.0 pts:** Fails to correct NVIC priority.

---

## Part D: Concurrency, Priority Inversion & HW/SW Debugging (25.0 Points Max, Floor: 17.5)

### Dimension D.1: Independent 3–5 Hypotheses Formulation (4.0 pts)
* **4.0 pts:** Formulates 3–5 plausible, competing, technical hypotheses before inspecting root causes. Hypotheses cover synchronization primitives, task starvation, watchdog refresh interval, and stack overflow.
* **2.0 pts:** Fewer than 3 hypotheses, or hypotheses are vague/non-discriminative.
* **0.0 pts:** No hypotheses stated.

### Dimension D.2: Two Independent Evidence Channels (6.0 pts)
* **6.0 pts:** Analyzes both Channel 1 (GDB task state: `Task_Compute` running, `Task_Telemetry` blocked on queue, `Task_Storage` holding lock with unboosted `uxPriority = 1`, `xMutexHolder == NULL` indicating binary semaphore) and Channel 2 (`RCC->CSR = 0x24000000` proving `IWDGRSTF=1`, timing trace showing > 500 ms starvation).
* **3.0 pts:** Analyzes only one evidence channel.
* **0.0 pts:** Cites no evidence channels.

### Dimension D.3: Root Cause & Real-Time Interaction (5.0 pts)
* **5.0 pts:** Accurately details the interacting failure mechanism: `xSemaphoreCreateBinary()` lacks priority inheritance. Medium task `Task_Compute` preempts Low task `Task_Storage`, which holds the lock. High task `Task_Telemetry` blocks. Because priority is not inherited, Medium task starves Low task, preventing `iwdg_refresh()`, triggering an autonomous IWDG reset.
* **3.0 pts:** Identifies binary semaphore vs mutex issue, but fails to connect it to watchdog starvation.
* **0.0 pts:** Identifies wrong root cause.

### Dimension D.4: Principled Fix (Mutex & Watchdog) (5.0 pts)
* **5.0 pts:** Replaces binary semaphore with `xSemaphoreCreateMutex()`. Retains proper watchdog refresh architecture. Rejects invalid timing hacks (`vTaskDelay()`, increasing watchdog window).
* **2.0 pts:** Uses mutex, but also inserts busy delays or disables watchdog.
* **0.0 pts:** Uses sleep/delay workarounds.

### Dimension D.5: Multi-Cycle Clean Regression Proof (5.0 pts)
* **5.0 pts:** Provides `make check` output confirming `xQueueCreateMutex` is invoked and the binary satisfies all concurrency contracts.
* **0.0 pts:** No regression proof.
