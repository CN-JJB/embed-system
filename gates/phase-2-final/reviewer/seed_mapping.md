# Phase 2 Final Gate: Seeded Defect & Variant Mapping

> **CONFIDENTIAL: REVIEWER REFERENCE MATERIALS — DO NOT DISTRIBUTE TO LEARNERS**

---

## Seed Catalog Overview

| Part | Competency Family | Seed ID | Defective File | Root Cause Mechanism | Reference Fix |
|---|---|---|---|---|---|
| **Part A** | Startup & Linker | `SEED-P2G-A4` | `part-a/linker/stm32f103c8tx_flash.ld` | Invalid `.data` LMA reference: `_sidata = _etext;` points to beginning of `.rodata` rather than `LOADADDR(.data)`, so startup copy loop copies `.rodata` bytes into RAM instead of initialized data. | Change `_sidata = _etext;` to `_sidata = LOADADDR(.data);` in `stm32f103c8tx_flash.ld`. |
| **Part B** | Peripheral & DMA | `SEED-P2G-B4` | `part-b/src/dma.c` | Non-circular channel termination: `DMA_CCR_CIRC` omitted in `DMA1_Channel1->CCR` (`CCR = 0x58E`), causing DMA to halt after first 128-sample block when CNDTR reaches 0; HT/TC counters freeze at 1. | Add `DMA_CCR_CIRC` to `DMA1_Channel1->CCR` configuration (`CCR = 0x5AE`). |
| **Part C** | Scheduler & NVIC | `SEED-P2G-C4` | `part-c/src/interrupt_config.c` | FreeRTOS syscall boundary violation: `NVIC_SetPriority(EXTI0_IRQn, 4)` configures hardware priority `0x40` (`0x40 < 0x50`), which cannot be masked by `BASEPRI`, corrupting scheduler on ISR API call. | Configure logical priority `6` (`NVIC_SetPriority(EXTI0_IRQn, 6)`), producing hardware byte `0x60 >= 0x50`. |
| **Part D** | Concurrency & Debug | `SEED-P2G-D4` | `part-d/src/node_app.c` | Mutex release mismatch / leak: `task_storage` acquires `xSensorBusLock` but releases `xLogBufferLock`, leaking `xSensorBusLock` and permanently blocking `task_telemetry`, starving `iwdg_refresh()`, provoking IWDG reset. | Change `xSemaphoreGive(xLogBufferLock)` to `xSemaphoreGive(xSensorBusLock)` in `task_storage`. |

---

## Detailed Seed Specifications

### Part A: SEED-P2G-A4
* **Competency Focus:** Linker script `_sidata` LMA assignment, memory layout with intervening read-only sections (`.rodata`, `.init_array`), startup copy loop (`Reset_Handler`).
* **Seeded Defect:** In `part-a/linker/stm32f103c8tx_flash.ld`, `_sidata = _etext;` is defined immediately after `.text`. Because `.rodata` and `.init_array` are placed in FLASH between `_etext` and `.data`, `_sidata` points to `.rodata` instead of the load memory address of `.data`.
* **Observable Manifestation:**
  - `arm-none-eabi-readelf -S build/firmware.elf` shows `.data` LMA is at `0x0800024c` (following `.rodata`), whereas symbol `_sidata` is at `0x0800020c` (`_etext`).
  - Runtime execution halts in `main()` fault loop because `g_boot_config_token != 0x5A5AA5A5U` (RAM received `.rodata` constants).
* **Expected Learner Output:** Identified mismatch between `_sidata` and `LOADADDR(.data)` via Binutils; corrected linker script by setting `_sidata = LOADADDR(.data);`.

### Part B: SEED-P2G-B4
* **Competency Focus:** STM32 DMA controller channel circular buffering mode (`DMA_CCR_CIRC`), continuous data streaming, transfer counters.
* **Seeded Defect:** In `part-b/src/dma.c`, `DMA1_Channel1->CCR` omits bit 5 (`CIRC`) (`CCR = 0x58E` without EN, `0x58F` with EN).
* **Observable Manifestation:**
  - GDB register dump shows `DMA1_Channel1->CCR = 0x0000058F` (bit 7 `MINC` is 1, bit 5 `CIRC` is 0).
  - `DMA1_Channel1->CNDTR = 0x00000000` (counter decremented to 0 and halted).
  - Double buffer `g_adc_buffer` shows valid 128 samples populated once during first block, but subsequent transfers cease.
  - Interrupt counts `g_dma_ht_count = 1` and `g_dma_tc_count = 1` (halted after first cycle; no circular reload).
* **Expected Learner Output:** Decoded raw `CCR` against RM0008 Section 10.4.3; diagnosed channel termination from omitted `CIRC`; added `DMA_CCR_CIRC` to `dma.c`.

### Part C: SEED-P2G-C4
* **Competency Focus:** Cortex-M3 NVIC priority byte encoding, CMSIS `NVIC_SetPriority()` bit shift, FreeRTOS `BASEPRI` syscall threshold.
* **Seeded Defect:** `NVIC_SetPriority(EXTI0_IRQn, 4)` configures logical priority 4, which is shifted left by 4 bits to hardware byte `0x40`.
* **Observable Manifestation:**
  - `(gdb) x/1bx 0xE000E406` reports `0x40`.
  - In Cortex-M, `0x40 < 0x50` (`configMAX_SYSCALL_INTERRUPT_PRIORITY`), meaning EXTI0 has higher urgency than the `BASEPRI` masking threshold.
  - Calling `xQueueSendFromISR()` inside `EXTI0_IRQHandler` triggers kernel assertion trap in `vPortValidateInterruptPriority()`.
* **Expected Learner Output:** Traced exception frame on PSP; audited raw NVIC byte `0x40`; recognized `0x40 < 0x50` syscall boundary violation; updated priority to logical 5 or 6 (`NVIC_SetPriority(EXTI0_IRQn, 6)`).

### Part D: SEED-P2G-D4
* **Competency Focus:** Real-time concurrency, lock release mismatch / unreleased mutex, watchdog refresh starvation, hardware independent watchdog (IWDG).
* **Seeded Defect:** `task_storage` acquires `xSensorBusLock` but releases `xLogBufferLock`, leaking `xSensorBusLock`. `task_telemetry` subsequently blocks indefinitely on `xSensorBusLock`.
* **Observable Manifestation:**
  - GDB thread dump shows `Task_Telemetry` in `Blocked` state waiting on `xSensorBusLock`, where `xMutexHolder` is `Task_Storage`.
  - `Task_Storage` subsequently deadlocks on next acquisition attempt.
  - Timing trace shows tasks freeze after t = 0.020 s.
  - Watchdog refresh is withheld indefinitely, causing hardware IWDG reset at t = 0.501 s (`RCC->CSR` shows `IWDGRSTF = 1`).
* **Expected Learner Output:** Diagnostic report; 2 independent evidence channels; recognized lock mismatch in `task_storage`; replaced `xSemaphoreGive(xLogBufferLock)` with `xSemaphoreGive(xSensorBusLock)` to restore normal execution and watchdog refresh.
