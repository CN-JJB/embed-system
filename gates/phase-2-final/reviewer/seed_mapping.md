# Phase 2 Final Gate: Seeded Defect & Variant Mapping

> **CONFIDENTIAL: REVIEWER REFERENCE MATERIALS — DO NOT DISTRIBUTE TO LEARNERS**

---

## Seed Catalog Overview

| Part | Competency Family | Seed ID | Defective File | Root Cause Mechanism | Reference Fix |
|---|---|---|---|---|---|
| **Part A** | Startup & Linker | `SEED-P2G-A2` | `part-a/linker/stm32f103c8tx_flash.ld` | Relocation LMA assignment mismatch: `_sidata = _etext;` ignores intervening `.rodata` and `.init_array` in Flash, loading `.data` with code bytes. | Assign `_sidata = LOADADDR(.data);` in linker script. |
| **Part B** | Peripheral & DMA | `SEED-P2G-B2` | `part-b/src/dma.c` | Omission of `DMA_CCR_CIRC` in `DMA1_Channel1->CCR` operates channel in single-buffer mode, halting acquisition after 128 samples. | Add `DMA_CCR_CIRC` to `DMA1_Channel1->CCR` configuration. |
| **Part C** | Scheduler & NVIC | `SEED-P2G-C2` | `part-c/src/interrupt_config.c` | Passing `configMAX_SYSCALL_INTERRUPT_PRIORITY` (`0x50`) to `NVIC_SetPriority` shifts to `0x00`, violating FreeRTOS syscall boundary. | Pass unshifted logical priority `5` (or `6`) to `NVIC_SetPriority(EXTI0_IRQn, 5)`. |
| **Part D** | Concurrency & Debug | `SEED-P2G-D2` | `part-d/src/node_app.c` | Inverted lock acquisition hierarchy between `task_telemetry` and `task_storage` creates AB-BA deadlock, starving watchdog refresh. | Enforce canonical lock acquisition order (`xSensorBusLock` before `xTelemetryBufferLock`) in `task_storage`. |

---

## Detailed Seed Specifications

### Part A: SEED-P2G-A2
* **Competency Focus:** Linker script LMA vs VMA address mapping, section layout, startup runtime relocation loop (`Reset_Handler`).
* **Seeded Defect:** In `part-a/linker/stm32f103c8tx_flash.ld`, `_sidata = _etext;` assigns the data copy source pointer to the end of `.text`. Because `.rodata` and `.init_array` follow `.text` in Flash, `_sidata` points to `.rodata` rather than `LOADADDR(.data)`.
* **Observable Manifestation:**
  - `arm-none-eabi-nm build/firmware.elf | grep _sidata` matches `_etext`.
  - `arm-none-eabi-readelf -l build/firmware.elf` reports `.data` PhysAddr greater than `_sidata`.
  - Runtime execution halts in `main()` fault loop because `g_boot_config_token != 0x5A5AA5A5U`.
* **Expected Learner Output:** Identified `_sidata` LMA discrepancy via Binutils; corrected linker script to `_sidata = LOADADDR(.data);`.

### Part B: SEED-P2G-B2
* **Competency Focus:** STM32 DMA controller channel configuration, circular buffer streaming, peripheral MMIO registers.
* **Seeded Defect:** In `part-b/src/dma.c`, `DMA1_Channel1->CCR` bit 5 (`CIRC`) is omitted (`CCR = 0x58e` instead of `0x5ae`).
* **Observable Manifestation:**
  - GDB register dump shows `DMA1_Channel1->CCR = 0x0000058F` (bit 5 is 0) and `CNDTR = 0x00000000`.
  - GDB memory dump shows initial 128 samples acquired once, but buffer never refreshes; `g_dma_ht_count` and `g_dma_tc_count` remain at 1.
* **Expected Learner Output:** Decoded raw `CCR` against RM0008 Section 10.4.3; recognized single-buffer behavior; added `DMA_CCR_CIRC` to `dma.c`.

### Part C: SEED-P2G-C2
* **Competency Focus:** Cortex-M3 NVIC priority byte encoding, CMSIS `NVIC_SetPriority()` bit shift, FreeRTOS `BASEPRI` syscall threshold.
* **Seeded Defect:** `NVIC_SetPriority(EXTI0_IRQn, 0x50)` passes the shifted priority constant `configMAX_SYSCALL_INTERRUPT_PRIORITY` (`0x50`). In CMSIS, this is shifted left by 4 bits: `(0x50 << 4) & 0xFF == 0x00`, configuring raw priority `0x00` (highest preemption priority 0).
* **Observable Manifestation:**
  - `(gdb) x/1bx 0xE000E406` reports `0x00`.
  - Calling `xQueueSendFromISR()` inside `EXTI0_IRQHandler` triggers kernel assertion trap in `vPortValidateInterruptPriority()`.
* **Expected Learner Output:** Traced exception frame on PSP; audited raw NVIC byte `0x00`; calculated that logical priority must be passed ($\ge 5$); changed argument to `5` or `6`.

### Part D: SEED-P2G-D2
* **Competency Focus:** Real-time concurrency, lock acquisition hierarchy, Coffman circular wait deadlock, hardware independent watchdog (IWDG).
* **Seeded Defect:** `task_telemetry` acquires `xSensorBusLock` then `xTelemetryBufferLock`. `task_storage` acquires `xTelemetryBufferLock` then `xSensorBusLock`. Under concurrent execution, both tasks block on each other.
* **Observable Manifestation:**
  - GDB thread dump shows both `Task_Telemetry` and `Task_Storage` in `Blocked` state waiting on mutual mutexes.
  - Logic analyzer trace shows execution windows freeze at t = 0.110 s.
  - Watchdog refresh is withheld indefinitely, causing hardware IWDG reset at t = 0.611 s (`RCC->CSR` shows `IWDGRSTF = 1`).
* **Expected Learner Output:** 8-step diagnostic report; 2 independent evidence channels; recognized circular wait deadlock; reordered locks in `task_storage` to enforce canonical acquisition order.
