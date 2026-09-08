# Phase 2 Final Gate: Detailed Reviewer Scoring Anchors

> **CONFIDENTIAL: REVIEWER REFERENCE MATERIALS — DO NOT DISTRIBUTE TO LEARNERS**

This document establishes concrete, point-by-point scoring anchors for each of the four Parts of the Phase 2 Final Gate assessment. Total available: **100.0 points**.

---

## Part A: Bare-Metal Startup & Linker Reasoning (25.0 Points Max, Floor: 15.0)

### Dimension A.1: Startup & Linker Mental Model (5.0 pts)
* **5.0 pts:** Accurately annotates all 7 startup phases (`MSP from vector 0`, `Thumb Reset_Handler entry`, `SystemInit under pre-.data/.bss invariant`, `.data LMA->VMA copy`, `.bss zeroing`, `__libc_init_array constructor dispatch`, and `main entry`). Explains LMA vs VMA distinction, why Flash contains initial data values that must be copied into SRAM, and why `.data` boundary calculation matters.
* **3.0 pts:** Minor omissions in startup sequence or misstates pre-runtime initialization invariant.
* **0.0 pts:** Fundamental confusion regarding vector table loading, Thumb bit, or memory initialization order.

### Dimension A.2: ELF / Symbol / Map Evidence (5.0 pts)
* **5.0 pts:** Provides verbatim output from `arm-none-eabi-readelf -l` (or `-S`) and `arm-none-eabi-nm` showing that `_sidata == 0x20000000` (matching the SRAM VMA of `.data`), while `.data` LOADADDR resides in Flash (`0x0800xxxx`), proving `_sidata` points to uninitialized RAM instead of Flash.
* **3.0 pts:** Identifies that `.data` was not copied from Flash, but evidence lacks verbatim tool outputs or symbol address calculation.
* **0.0 pts:** Fabricated evidence, or no Binutils inspection performed.

### Dimension A.3: Root Cause Reasoning (5.0 pts)
* **5.0 pts:** Explicitly articulates why assigning `_sidata = ADDR(.data);` causes the startup relocation pointer to resolve to the SRAM VMA (`0x20000000`) rather than the Flash LMA (`LOADADDR(.data)`). Because `_sidata` equals `_sdata`, the startup `Reset_Handler` copy loop copies uninitialized SRAM into SRAM instead of loading the compiled data initializers from Flash.
* **3.0 pts:** States that `_sidata` was wrong, but does not explain how VMA assignment caused the uninitialized RAM self-copy.
* **0.0 pts:** Guesses unrelated causes (e.g. clock failure, wrong optimization level).

### Dimension A.4: Minimal Principled Correction (5.0 pts)
* **5.0 pts:** Corrects `linker/stm32f103c8tx_flash.ld` by replacing `_sidata = ADDR(.data);` with `_sidata = LOADADDR(.data);`. Does not introduce unneeded changes or disable sections.
* **2.5 pts:** Hardcodes Flash offset or modifies section order unsafely.
* **0.0 pts:** Fails to repair the linker script.

### Dimension A.5: Automated Regression Proof (5.0 pts)
* **5.0 pts:** Provides verbatim output of `make check` / regression oracle passing, confirming `_sidata == LOADADDR(.data)` and data initialization contract verified.
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
* **5.0 pts:** Accurately maps the autonomous trigger chain from `TIM3->CR2` (`MMS=010`), `ADC1->CR2` (`EXTSEL=100`, `EXTTRIG=1`, `DMA=1`), to `DMA1_Channel1->CPAR` / `CMAR` / `CNDTR`.
* **3.0 pts:** Confuses ADC software start with external hardware timer triggering.
* **0.0 pts:** Fails to trace peripheral data-path connection.

### Dimension B.3: Buffer & Interrupt Lifecycle Reasoning (5.0 pts)
* **5.0 pts:** Explains why continuous circular acquisition resulted in only `g_adc_buffer[0][0]` being populated: `DMA_CCR_MINC` (bit 7) was omitted (`CCR = 0x52F` with EN). While `DMA_CCR_CIRC` (bit 5) enabled circular reloading (proved by 142 HT/TC interrupt events), the memory pointer never incremented, continually overwriting index 0.
* **3.0 pts:** Identifies that only slot 0 has data, but cannot explain register reason (`MINC=0`).
* **0.0 pts:** Claims DMA never started or buffer was corrupted.

### Dimension B.4: Observable Evidence & Non-Proof (5.0 pts)
* **5.0 pts:** Accurately cites register bit values from `register_dump.txt` (`CCR = 0x0000052F`, bit 7 = 0) and buffer dump (slot 0 updated, slots 1..127 blank, 142 interrupts). Formulates clear Non-Proof statement: *"Static register verification does not prove analog input voltages were accurate or conversions were noise-free."*
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
* **5.0 pts:** Explains that configuring logical priority 3 (`NVIC_SetPriority(EXTI0_IRQn, 3)`) results in hardware priority byte `0x30` (`(3 << 4) & 0xFF = 0x30`). In Cortex-M, numerically lower values indicate higher urgency. Because `0x30 < 0x50` (`configMAX_SYSCALL_INTERRUPT_PRIORITY`), EXTI0 has higher urgency than `BASEPRI` and is not masked during FreeRTOS critical sections, causing kernel assertion failures when invoking `FromISR` APIs.
* **3.0 pts:** Identifies priority violation, but confuses priority numerical order or masking behavior.
* **0.0 pts:** Claims priority 3 is lower priority and therefore safe.

### Dimension C.4: Evidence Interpretation & Non-Proof (5.0 pts)
* **5.0 pts:** Provides disciplined interpretation of GDB trace (`NVIC->IP[EXTI0_IRQn] = 0x30`) and explains Non-Proof: *"A single valid breakpoint trace does not prove the system is free from priority inversion or race conditions under arbitrary interrupt arrival patterns."*
* **3.0 pts:** Reasonable interpretation, but weak Non-Proof limits.
* **0.0 pts:** No evidence analysis.

### Dimension C.5: Priority Repair & Calculation Proof (5.0 pts)
* **5.0 pts:** Modifies `src/interrupt_config.c` to configure logical priority $\ge 5$ (e.g. 5 or 6, producing hardware byte `0x50` or `0x60`). Provides `make check` passing proof.
* **0.0 pts:** Fails to correct NVIC priority.

---

## Part D: Concurrency, Priority Inversion & HW/SW Debugging (25.0 Points Max, Floor: 17.5)

### Dimension D.1: Independent 3–5 Hypotheses Formulation (4.0 pts)
* **4.0 pts:** Formulates 3–5 plausible, competing, technical hypotheses before inspecting root causes. Hypotheses cover unreleased mutex leak, task starvation, priority inversion, watchdog refresh starvation, and queue timeout exhaustion.
* **2.0 pts:** Fewer than 3 hypotheses, or hypotheses are vague/non-discriminative.
* **0.0 pts:** No hypotheses stated.

### Dimension D.2: Two Independent Evidence Channels (6.0 pts)
* **6.0 pts:** Analyzes both Channel 1 (GDB task state: `task_telemetry` blocked on `xSensorBusLock` where `xMutexHolder` is `task_storage`; unreleased lock leak confirmed) and Channel 2 (`RCC->CSR = 0x24000000` proving `IWDGRSTF=1`, watchdog reset after 501 ms starvation; LSI nominal 40 kHz, PR=/64, RLR=312 giving 500.8 ms nominal timeout, within [334 ms, 668 ms] tolerance window).
* **3.0 pts:** Analyzes only one evidence channel.
* **0.0 pts:** Cites no evidence channels.

### Dimension D.3: Root Cause & Real-Time Interaction (5.0 pts)
* **5.0 pts:** Accurately details the interacting failure mechanism: `task_storage` acquires `xSensorBusLock` and omits `xSemaphoreGive()`. Mutex leakage causes `task_telemetry` to block indefinitely, preventing it from executing `iwdg_refresh()`, triggering hardware independent watchdog reset at ~500 ms.
* **3.0 pts:** Identifies unreleased lock, but fails to connect it to watchdog starvation.
* **0.0 pts:** Identifies wrong root cause.

### Dimension D.4: Principled Fix (Lock Hierarchy & Watchdog Retention) (5.0 pts)
* **5.0 pts:** Adds `xSemaphoreGive(xSensorBusLock)` in `task_storage` inside `src/node_app.c`. Retains proper watchdog refresh architecture. Rejects invalid timing hacks (`vTaskDelay()`, increasing watchdog window, removing locks).
* **2.0 pts:** Eliminates failure by disabling locking or removing mutex protections.
* **0.0 pts:** Uses sleep/delay workarounds.

### Dimension D.5: Multi-Cycle Clean Regression Proof (5.0 pts)
* **5.0 pts:** Provides `make check` output confirming mutex release pairing is verified and binary satisfies all concurrency contracts.
* **0.0 pts:** No regression proof.

