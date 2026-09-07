# Phase 2 Final Gate: Seeded Defect & Variant Mapping

> **CONFIDENTIAL: REVIEWER REFERENCE MATERIALS — DO NOT DISTRIBUTE TO LEARNERS**

---

## Seed Catalog Overview

| Part | Competency Family | Seed ID | Defective File | Root Cause Mechanism | Reference Fix |
|---|---|---|---|---|---|
| **Part A** | Startup & Linker | `SEED-P2G-A3` | `part-a/linker/stm32f103c8tx_flash.ld` | Empty `.data` relocation range: `_edata = .;` is positioned before `*(.data*)`, yielding `_edata == _sdata == 0x20000000` (length 0 bytes), so the startup copy loop skips initial data copy. | Move `_edata = .;` after `*(.data*)` in `stm32f103c8tx_flash.ld`. |
| **Part B** | Peripheral & DMA | `SEED-P2G-B3` | `part-b/src/dma.c` | Destination pointer stagnation: `DMA_CCR_MINC` omitted in `DMA1_Channel1->CCR` (`CCR = 0x52E`), causing all samples to overwrite buffer index 0 while rest of buffer remains blank. | Add `DMA_CCR_MINC` to `DMA1_Channel1->CCR` configuration (`CCR = 0x5AE`). |
| **Part C** | Scheduler & NVIC | `SEED-P2G-C3` | `part-c/src/interrupt_config.c` | FreeRTOS syscall boundary violation: `NVIC_SetPriority(EXTI0_IRQn, 3)` configures hardware priority `0x30` (`0x30 < 0x50`), which cannot be masked by `BASEPRI`, corrupting scheduler on ISR API call. | Configure logical priority `6` (`NVIC_SetPriority(EXTI0_IRQn, 6)`), producing hardware byte `0x60 >= 0x50`. |
| **Part D** | Concurrency & Debug | `SEED-P2G-D3` | `part-d/src/node_app.c` | Mutex unreleased leak: `task_storage` acquires `xSensorBusLock` and omits `xSemaphoreGive()`, permanently blocking `task_telemetry` and starving `iwdg_refresh()`, provoking IWDG reset. | Add `xSemaphoreGive(xSensorBusLock)` in `task_storage`. |

---

## Detailed Seed Specifications

### Part A: SEED-P2G-A3
* **Competency Focus:** Linker script location counter `.` manipulation, section output bounds, startup runtime copy loop (`Reset_Handler`).
* **Seeded Defect:** In `part-a/linker/stm32f103c8tx_flash.ld`, `_edata = .;` is defined before `*(.data*)`. Consequently, `_edata` equals `_sdata` (`0x20000000`), collapsing the startup relocation loop to 0 bytes.
* **Observable Manifestation:**
  - `arm-none-eabi-nm build/firmware.elf | grep -E '_sdata|_edata'` reports `_sdata == _edata == 0x20000000`.
  - `readelf -S` shows non-empty `.data` section in image, but startup bounds span 0 bytes.
  - Runtime execution halts in `main()` fault loop because `g_boot_config_token != 0x5A5AA5A5U`.
* **Expected Learner Output:** Identified `_edata == _sdata` anomaly via Binutils; corrected linker script by placing `_edata = .;` after `*(.data*)`.

### Part B: SEED-P2G-B3
* **Competency Focus:** STM32 DMA controller channel configuration, memory increment (`MINC`), peripheral MMIO registers.
* **Seeded Defect:** In `part-b/src/dma.c`, `DMA1_Channel1->CCR` omits bit 7 (`MINC`) (`CCR = 0x52E` without EN, `0x52F` with EN).
* **Observable Manifestation:**
  - GDB register dump shows `DMA1_Channel1->CCR = 0x0000052F` (bit 7 `MINC` is 0, bit 5 `CIRC` is 1).
  - GDB memory dump shows `g_adc_buffer[0][0] = 0x073A`, while indices 1..127 remain `0x0000`.
  - Interrupt counts `g_dma_ht_count` and `g_dma_tc_count` advance continuously (142 counts), proving DMA active but stagnant in memory destination.
* **Expected Learner Output:** Decoded raw `CCR` against RM0008 Section 10.4.3; diagnosed memory pointer stagnation from omitted `MINC`; added `DMA_CCR_MINC` to `dma.c`.

### Part C: SEED-P2G-C3
* **Competency Focus:** Cortex-M3 NVIC priority byte encoding, CMSIS `NVIC_SetPriority()` bit shift, FreeRTOS `BASEPRI` syscall threshold.
* **Seeded Defect:** `NVIC_SetPriority(EXTI0_IRQn, 3)` configures logical priority 3, which is shifted left by 4 bits to hardware byte `0x30`.
* **Observable Manifestation:**
  - `(gdb) x/1bx 0xE000E406` reports `0x30`.
  - In Cortex-M, `0x30 < 0x50` (`configMAX_SYSCALL_INTERRUPT_PRIORITY`), meaning EXTI0 has higher urgency than the `BASEPRI` masking threshold.
  - Calling `xQueueSendFromISR()` inside `EXTI0_IRQHandler` triggers kernel assertion trap in `vPortValidateInterruptPriority()`.
* **Expected Learner Output:** Traced exception frame on PSP; audited raw NVIC byte `0x30`; recognized `0x30 < 0x50` syscall boundary violation; updated priority to logical 5 or 6 (`NVIC_SetPriority(EXTI0_IRQn, 6)`).

### Part D: SEED-P2G-D3
* **Competency Focus:** Real-time concurrency, lock leak / unreleased mutex, watchdog refresh starvation, hardware independent watchdog (IWDG).
* **Seeded Defect:** `task_storage` acquires `xSensorBusLock` and omits `xSemaphoreGive(xSensorBusLock)`. `task_telemetry` subsequently blocks indefinitely on `xSensorBusLock`.
* **Observable Manifestation:**
  - GDB thread dump shows `Task_Telemetry` in `Blocked` state waiting on `xSensorBusLock`, where `xMutexHolder` is `Task_Storage`.
  - Timing trace shows tasks freeze after t = 0.105 s.
  - Watchdog refresh is withheld indefinitely, causing hardware IWDG reset at t = 0.601 s (`RCC->CSR` shows `IWDGRSTF = 1`).
* **Expected Learner Output:** 8-step diagnostic report; 2 independent evidence channels; recognized unreleased mutex in `task_storage`; added `xSemaphoreGive(xSensorBusLock)` to restore normal execution and watchdog refresh.
