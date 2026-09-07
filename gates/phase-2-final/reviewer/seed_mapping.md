# Phase 2 Final Gate: Seeded Defect & Variant Mapping

> **CONFIDENTIAL: REVIEWER REFERENCE MATERIALS — DO NOT DISTRIBUTE TO LEARNERS**

---

## Seed Catalog Overview

| Part | Competency Family | Seed ID | Defective File | Root Cause Mechanism | Reference Fix |
|---|---|---|---|---|---|
| **Part A** | Startup & Linker | `SEED-P2G-A1` | `part-a/linker/stm32f103c8tx_flash.ld` | Missing `KEEP(*(.init_array*))` under `-Wl,--gc-sections` discards pre-main constructor function pointers. | Add `KEEP(*(.init_array*))` to `.init_array` section in linker script. |
| **Part B** | Peripheral & DMA | `SEED-P2G-B1` | `part-b/src/dma.c` | Omission of `DMA_CCR_MINC` in `DMA1_Channel1->CCR` keeps memory destination pointer frozen at index 0. | Add `DMA_CCR_MINC` to `DMA1_Channel1->CCR` configuration. |
| **Part C** | Scheduler & NVIC | `SEED-P2G-C1` | `part-c/src/interrupt_config.c` | `NVIC_SetPriority(EXTI0_IRQn, 4)` encodes priority `0x40`, violating `configMAX_SYSCALL_INTERRUPT_PRIORITY` (`0x50`). | Set `NVIC_SetPriority(EXTI0_IRQn, 6)` (or any value $\ge 5$). |
| **Part D** | Concurrency & Debug | `SEED-P2G-D1` | `part-d/src/node_app.c` | `xSemaphoreCreateBinary()` lacks priority inheritance, causing unbounded priority inversion and IWDG watchdog reset. | Replace with `xSemaphoreCreateMutex()` to activate FreeRTOS priority inheritance. |

---

## Detailed Seed Specifications

### Part A: SEED-P2G-A1
* **Competency Focus:** Linker script directives, `--gc-sections`, C runtime constructors (`__libc_init_array()`).
* **Seeded Defect:** In `part-a/linker/stm32f103c8tx_flash.ld`, `.init_array` uses `*(.init_array*)` without `KEEP()`.
* **Observable Manifestation:**
  - `arm-none-eabi-readelf -W -S build/firmware.elf | grep '\.init_array'` reports size `000000`.
  - `arm-none-eabi-nm build/firmware.elf` lacks `system_peripheral_preinit`.
  - Runtime execution halts in `main()` trap loop because `g_boot_preinit_token == 0`.
* **Expected Learner Output:** Identified missing `KEEP` in linker script; preserved `.init_array` entries.

### Part B: SEED-P2G-B1
* **Competency Focus:** STM32 DMA controller memory addressing, circular double buffering, MMIO register configuration.
* **Seeded Defect:** In `part-b/src/dma.c`, `DMA1_Channel1->CCR` bit 7 (`MINC`) is omitted (`CCR = 0x52e` instead of `0x5ae`).
* **Observable Manifestation:**
  - Memory dump shows `g_adc_buffer[0]` receives conversions, but `g_adc_buffer[1..127]` remain `0x0000`.
  - Register dump shows `CCR = 0x00002527` (bit 7 is 0).
* **Expected Learner Output:** Calculated ADC/timer rates; identified `MINC=0`; modified `dma.c` to add `DMA_CCR_MINC`.

### Part C: SEED-P2G-C1
* **Competency Focus:** Cortex-M3 exception model, NVIC priority registers, FreeRTOS `BASEPRI` masking threshold.
* **Seeded Defect:** `NVIC_SetPriority(EXTI0_IRQn, 4)` sets logical priority 4 (`0x40`), which is higher hardware priority than `configMAX_SYSCALL_INTERRUPT_PRIORITY` (`0x50`).
* **Observable Manifestation:**
  - `NVIC->IP[EXTI0_IRQn] = 0x40`.
  - FreeRTOS assertion traps inside `vPortValidateInterruptPriority()`.
* **Expected Learner Output:** Traced exception frame on PSP; calculated new top of stack `0x200011F0`; audited priority byte `0x40 < 0x50`; changed priority to $\ge 5$.

### Part D: SEED-P2G-D1
* **Competency Focus:** Real-time concurrency, priority inversion, mutual exclusion vs binary synchronization, independent watchdog (IWDG).
* **Seeded Defect:** `xSharedResourceLock = xSemaphoreCreateBinary();` does not track mutex owner and provides no priority inheritance.
* **Observable Manifestation:**
  - GDB inspection shows `Task_Compute` (Priority 2) running while `Task_Storage` (Priority 1) holds lock, blocking `Task_Telemetry` (Priority 3).
  - `Task_Storage` priority is not elevated (`uxPriority = 1`).
  - Starvation prevents `iwdg_refresh()`, triggering `RCC_CSR_IWDGRSTF` reset.
* **Expected Learner Output:** 8-step diagnostic record; 2 independent evidence channels; replaced with `xSemaphoreCreateMutex()`.
