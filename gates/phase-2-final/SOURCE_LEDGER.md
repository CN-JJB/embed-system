# SOURCE LEDGER — Phase 2 Final Gate Assessment Package

This document binds all primary technical specifications, processor manuals, and upstream source code repositories to the Phase 2 Final Gate assessment tasks (Parts A, B, C, and D).

---

## 1. Upstream Open-Source Software Components

### 1.1 FreeRTOS-Kernel
* **Organization:** FreeRTOS / Amazon Web Services
* **Repository:** `https://github.com/FreeRTOS/FreeRTOS-Kernel`
* **Release:** **V11.3.0**
* **Exact Commit:** `9b777ae5c5b8e9e456065a00294d1e5f5f9facf5`
* **License:** MIT License
* **Source Path:** `fundamentals/rtos/vendor/freertos/`
* **Gate Part Binding:**
  - **Part C:** Core scheduling (`tasks.c`, `list.c`), Cortex-M3 port (`portable/GCC/ARM_CM3/port.c`), PendSV context switch, exception return, and `vPortValidateInterruptPriority()`.
  - **Part D:** Synchronization primitives (`queue.c`), mutex with priority inheritance (`xQueueCreateMutex`), task stack watermarks (`uxTaskGetStackHighWaterMark`), and heap management (`portable/MemMang/heap_4.c`).
* **Reason:** Canonical real-time operating system kernel for Phase 2.
* **Verification Date:** 2026-09-07

### 1.2 CMSIS_5 (Cortex Microcontroller Software Interface Standard)
* **Organization:** Arm Limited
* **Repository:** `https://github.com/ARM-software/CMSIS_5`
* **Release:** **v5.9.0**
* **Exact Commit:** `2b7495b8535bdcb306dac29b9ded4cfb679d7e5c`
* **License:** Apache License 2.0
* **Source Path:** `fundamentals/mcu/vendor/cmsis/include/core_cm3.h`
* **Gate Part Binding:**
  - **Part A:** Core registers, SCB definitions, intrinsic barrier instructions (`__DSB()`, `__ISB()`).
  - **Part B:** NVIC functions (`NVIC_EnableIRQ`, `NVIC_SetPriority`).
  - **Part C:** SCB ICSR register, SysTick definitions, `NVIC_GetPriority()`, priority shift calculations.
  - **Part D:** DWT cycle counter registers (`DWT->CYCCNT`), CoreDebug trace enable.
* **Reason:** Authoritative register definitions and processor core access for Cortex-M3.
* **Verification Date:** 2026-09-07

### 1.3 cmsis-device-f1
* **Organization:** STMicroelectronics
* **Repository:** `https://github.com/STMicroelectronics/cmsis-device-f1`
* **Release:** **v4.3.5**
* **Exact Commit:** `8a76309ed1250d817e9c888c4417171d2ba3ba63`
* **License:** Apache License 2.0
* **Source Path:** `fundamentals/mcu/vendor/cmsis/include/stm32f103xb.h`
* **Gate Part Binding:**
  - **Part A:** Reset & Clock Control (RCC) registers, Flash memory base definitions.
  - **Part B:** TIM3 registers (`CR1`, `CR2`, `SMCR`, `DIER`, `SR`, `PSC`, `ARR`), ADC1 registers (`CR1`, `CR2`, `SMPR2`, `SQR3`, `DR`), DMA1 registers (`CCR1`, `CNDTR1`, `CPAR1`, `CMAR1`, `ISR`, `IFCR`).
  - **Part C:** Peripheral IRQ number enumerations (`TIM3_IRQn`, `DMA1_Channel1_IRQn`, `EXTI0_IRQn`).
  - **Part D:** USART1 registers (`SR`, `DR`, `BRR`, `CR1`), IWDG registers (`KR`, `PR`, `RLR`, `SR`), RCC reset flag `RCC_CSR_IWDGRSTF`.
* **Reason:** Authoritative device peripheral register bit masks and memory structures.
* **Verification Date:** 2026-09-07

---

## 2. Primary Silicon & Architecture Specifications

### 2.1 STMicroelectronics RM0008 Reference Manual
* **Organization:** STMicroelectronics
* **Document ID:** DocID 13902 Rev 21 (February 2021)
* **Source Tier:** Tier 1 (Silicon Vendor Reference Specification)
* **License:** Proprietary / STMicroelectronics Copyright
* **Gate Part Binding & Key Sections:**
  - **Part A (Section 3.5 & 6.2):** Vector table boot aliasing at `0x00000000` / `0x08000000`; RCC clock tree distribution.
  - **Part B (Sections 10.4, 11.4, 11.12, 14.4):**
    * TIM3 Master Mode Selection (`MMS = 010` update event as TRGO);
    * ADC1 regular external trigger (`EXTSEL = 100`, `EXTTRIG = 1`);
    * ADC clock prescaler $f_{\text{ADC}} \le 14\text{ MHz}$ (`ADCPRE = /6` giving 12 MHz);
    * ADC calibration sequence (`RSTCAL`, `CAL`);
    * DMA1 Channel 1 circular mode (`CIRC`), memory increment (`MINC`), halfword size (`PSIZE=01`, `MSIZE=01`), `IFCR` write-1-to-clear.
  - **Part C (Section 9.1):** NVIC interrupt vector assignments and interrupt request lines.
  - **Part D (Sections 19 & 27):** IWDG key registers (`0x5555`, `0xAAAA`, `0xCCCC`), reload counters, USART asynchronous transmit data register and flags.
* **Reason:** Silicon behavioral contract for all on-chip STM32F103 peripherals.
* **Verification Date:** 2026-09-07

### 2.2 STMicroelectronics DS5319 Datasheet
* **Organization:** STMicroelectronics
* **Document ID:** DocID 13587 Rev 20 (31 July 2025)
* **Source Tier:** Tier 1 (Electrical & Memory Limits)
* **License:** Proprietary / STMicroelectronics Copyright
* **Gate Part Binding & Key Sections:**
  - **Part A (Section 4):** Memory mapping: 64 KB Flash boundary (`0x0800FFFF`), 20 KB SRAM boundary (`0x20004FFF`).
  - **Part B (Section 5.3.18):** ADC electrical limits: maximum clock 14 MHz, sample time vs source impedance table.
  - **Part D (Section 5.3.15):** IWDG LSI frequency tolerance (30 kHz min, 40 kHz typ, 60 kHz max).
* **Reason:** Hardware boundary constraints and physical timing limits.
* **Verification Date:** 2026-09-07

### 2.3 STMicroelectronics PM0056 Cortex-M3 Programming Manual
* **Organization:** STMicroelectronics
* **Document ID:** DocID 15491 Rev 7 (December 2024)
* **Source Tier:** Tier 1 (Processor Core Specification)
* **License:** Proprietary / STMicroelectronics Copyright
* **Gate Part Binding & Key Sections:**
  - **Part A (Sections 2.1 & 4.4):** Reset vector fetching, MSP initialization, System Control Block (`SCB->VTOR`).
  - **Part C (Section 4.3):** NVIC priority register encoding, 4-bit priority field placement (bits [7:4]), priority grouping.
* **Reason:** Arm Cortex-M3 programming model on STM32 implementations.
* **Verification Date:** 2026-09-07

### 2.4 Armv7-M Architecture Reference Manual
* **Organization:** Arm Limited
* **Document ID:** Arm DDI 0403E.e (Issue E.e)
* **Source Tier:** Tier 1 (Architecture Contract)
* **License:** Proprietary / Arm Limited Copyright
* **Gate Part Binding & Key Sections:**
  - **Part A (Section B1.5):** Exception model, reset entry sequence, Thumb bit (bit 0 = 1) requirement for instruction branches.
  - **Part C (Sections B1.5.6, B1.5.7, B1.5.8):** Exception stack frame (`r0-r3, r12, lr, pc, xpsr`), Thread vs Handler mode, MSP vs PSP selection, `EXC_RETURN` codes (`0xFFFFFFFD`).
  - **Part D (Section B3.5):** Memory barriers (`DSB`, `ISB`) and processor state control.
* **Reason:** Foundational processor architecture semantics for Cortex-M3.
* **Verification Date:** 2026-09-07
