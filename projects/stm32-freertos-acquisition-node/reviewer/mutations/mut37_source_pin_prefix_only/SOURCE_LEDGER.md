# SOURCE LEDGER — Phase 2 P2-M07 STM32 FreeRTOS Acquisition Node

This document tracks all primary hardware manuals, processor architecture specifications, and upstream open-source software libraries utilized by the P2-M07 integration project.

---

## Primary Hardware & Architecture References

### 1. STMicroelectronics RM0008 Reference Manual
- **Organization**: STMicroelectronics
- **Document**: RM0008 Reference Manual: STM32F101xx, STM32F102xx, STM32F103xx, STM32F105xx and STM32F107xx advanced Arm-based 32-bit MCUs
- **Revision**: Rev 21 (February 2021)
- **Source Tier**: Tier 1 (Silicon Vendor Primary Documentation)
- **License**: Proprietary / STMicroelectronics Copyright
- **Pedagogical Scope & Invariants**:
  - **Section 6 (RCC)**: Clock tree configuration (8 MHz HSE to 72 MHz PLLMUL9, AHB /1, APB1 /2, APB2 /1, ADCPRE /6).
  - **Section 10 (DMA1)**: Channel 1 circular mode (`CIRC=1`), memory increment (`MINC=1`), 16-bit halfword transfers (`PSIZE=01`, `MSIZE=01`), Half-Transfer (`HTIF1`) and Transfer-Complete (`TCIF1`) interrupt flags, `IFCR` atomic clearing.
  - **Section 11 (ADC1)**: External trigger conversion triggered by TIM3 TRGO (`EXTSEL=100`, `EXTTRIG=1`), ADC DMA request generation (`DMA=1`), 55.5 cycles sample time (`SMP0=101`), `RSTCAL` and `CAL` calibration sequences.
  - **Section 14 (TIM3)**: 1.0 kHz periodic trigger generation (`PSC=71`, `ARR=999`), Master Mode Selection (`MMS=010` update as TRGO).
  - **Section 19 (IWDG)**: Independent watchdog direct register interface (`KR=0x5555`, `PR`, `RLR`, `KR=0xAAAA`, status flags `PVU`/`RVU`).
  - **Section 27 (USART1)**: Direct register asynchronous serial transmission (`SR_TXE`, `DR`, `BRR=0x0271` for 115200 baud @ 72 MHz APB2).
- **Verification Date**: 2026-09-06

### 2. STMicroelectronics DS5319 Datasheet
- **Organization**: STMicroelectronics
- **Document**: DS5319: STM32F103x8, STM32F103xB Medium-density performance line Arm-based 32-bit MCU
- **Revision**: Rev 20 (31 July 2025)
- **Source Tier**: Tier 1 (Silicon Electrical Specification)
- **License**: Proprietary / STMicroelectronics Copyright
- **Pedagogical Scope & Invariants**:
  - **Section 5.3.18 (ADC characteristics)**: Maximum allowed $f_{\text{ADC}} \le 14\text{ MHz}$; with 72 MHz PCLK2, ADCPRE /6 gives 12 MHz ($\le 14$ MHz).
  - **Section 5.3.4 (Embedded memory limits)**: Physical memory limits: 64 KB Flash ($0x08000000$), 20 KB SRAM ($0x20000000$).
- **Verification Date**: 2026-09-06

### 3. STMicroelectronics PM0056 Programming Manual
- **Organization**: STMicroelectronics
- **Document**: PM0056: STM32F10xxx/20xxx/21xxx/L1xxxx Cortex-M3 programming manual
- **Revision**: Rev 7 (December 2024)
- **Source Tier**: Tier 1 (Core Programming Reference)
- **License**: Proprietary / STMicroelectronics Copyright
- **Pedagogical Scope & Invariants**:
  - **Section 4.3 (NVIC)**: Cortex-M3 Nested Vectored Interrupt Controller: 4 bits of preemption priority implemented in STM32F103; priority grouping 0 (`NVIC_SetPriorityGrouping(0)`).
  - **Section 4.4 (SCB)**: System Control Block, `SCB->VTOR` vector table offset register.
- **Verification Date**: 2026-09-06

### 4. Armv7-M Architecture Reference Manual
- **Organization**: Arm Limited
- **Document**: Arm DDI 0403E.e (Issue E.e)
- **Source Tier**: Tier 1 (Architecture Specification)
- **License**: Proprietary / Arm Limited Copyright
- **Pedagogical Scope & Invariants**:
  - **Section B3.5 (Data Synchronization Barrier)**: `__DSB()` semantics to guarantee write buffer drain to memory-mapped peripheral control registers before exiting exception handlers.
  - **Section C1.8 (Debug and Trace)**: CoreDebug DEMCR TRCENA and DWT (Data Watchpoint and Trace) CYCCNT 32-bit cycle counter operation.
- **Verification Date**: 2026-09-06

---

## Upstream Open-Source Software Components

### 5. FreeRTOS-Kernel
- **Organization**: FreeRTOS / Amazon Web Services
- **Repository**: `https://github.com/FreeRTOS/FreeRTOS-Kernel`
- **Release**: **V11.3.0**
- **Exact Commit**: `9b777ae5ffffffffffffffffffffffffffffffff`
- **License**: MIT License (`LICENSE.md`)
- **Components Utilized**:
  - Core scheduler: `tasks.c`, `list.c`
  - Synchronization: `queue.c` (queue FromISR handoff, priority inherit/disinherit mutexes)
  - Port layer: `portable/GCC/ARM_CM3/port.c` (SVCall, PendSV, SysTick)
  - Memory manager: `portable/MemMang/heap_4.c` (first-fit with block coalescing, `ucHeap` sole allocator)
- **Pedagogical Scope & Invariants**:
  - Zero dynamic memory allocation after system steady state.
  - Priority hierarchy: `Task_Process` (3) > `Task_Comm` (2) = `Task_Compute` (2) > `Task_Health` (1).
  - DMA IRQ logical priority 6 (safe for `configMAX_SYSCALL_INTERRUPT_PRIORITY = 5`).
- **Verification Date**: 2026-09-06

### 6. CMSIS_5
- **Organization**: Arm Limited
- **Repository**: `https://github.com/ARM-software/CMSIS_5`
- **Release**: **v5.9.0**
- **Exact Commit**: `2b7495b8535bdcb306dac29b9ded4cfb679d7e5c`
- **License**: Apache License 2.0 (`LICENSE.CMSIS_5`)
- **Components Utilized**:
  - Core header: `core_cm3.h` (NVIC functions, DWT registers, intrinsics `__NOP`, `__DSB`, `__disable_irq`).
- **Verification Date**: 2026-09-06

### 7. cmsis-device-f1
- **Organization**: STMicroelectronics
- **Repository**: `https://github.com/STMicroelectronics/cmsis-device-f1`
- **Release**: **v4.3.5**
- **Exact Commit**: `8a76309ed1250d817e9c888c4417171d2ba3ba63`
- **License**: Apache License 2.0 (`LICENSE.cmsis-device-f1`)
- **Components Utilized**:
  - Device header: `stm32f103xb.h` (register structures, peripheral bit masks, IRQn enum).
- **Verification Date**: 2026-09-06

---

## Build Toolchain Environment

| Component | Canonical Project Baseline | Host Environment Actually Used |
|---|---|---|
| Architecture | Arm Cortex-M3 (Armv7-M) | Arm Cortex-M3 (Armv7-M) |
| Toolchain | Arm GNU Toolchain 13.3.rel1 | Ubuntu/Debian arm-none-eabi-gcc 13.2.rel1-2 (GCC 13.2.1) |
| Assembler & Linker | GNU Binutils 2.42 | GNU Binutils 2.42 |
| C Library Runtime | Newlib-nano 4.4.0 (`--specs=nano.specs --specs=nosys.specs`) | Newlib-nano 4.4.0 |
| Dynamic Memory | FreeRTOS heap_4 (`configTOTAL_HEAP_SIZE = 9216`) | FreeRTOS heap_4 |
| Startup Model | Course-owned `startup_stm32f103c8.s` (`-nostartfiles`) | Course-owned `startup_stm32f103c8.s` (`-nostartfiles`) |
| Compiler Flags | `-mcpu=cortex-m3 -mthumb -O2 -g3 -Wall -Wextra -Werror` | `-mcpu=cortex-m3 -mthumb -O2 -g3 -Wall -Wextra -Werror` |
