# P2-M02 Source Ledger

This document registers the authoritative upstream specifications, registers, and architectural documents for Module P2-M02.

| Upstream / Project | Organization | Tier | Exact Revision / Version / Commit | Exact File / Path / Section | License | Why Pedagogically Useful | Verification Date |
|---|---|---|---|---|---|---|---|
| **ST Reference Manual RM0008** | STMicroelectronics | Tier 1 (Primary Vendor Spec) | DocID 13902 Rev 21 (Feb 2021) | Section 3.3.3 (Flash latency), Section 6 (RCC), Section 9 (GPIO), Section 10 (Interrupts/NVIC), Section 14 (TIM2/3/4) | Proprietary (ST Reference Manual) | Authoritative clock tree diagram, APB1 prescaler timer doubling rule, BSRR/BRR atomic registers, TIM2 registers. | 2026-09-03 |
| **ST Programming Manual PM0056** | STMicroelectronics | Tier 1 (Core Programming Model) | DocID 15491 Rev 7 (Dec 2024) | Section 2.1 (Modes and stacks), Section 4.3 (NVIC), Section 4.4 (SCB) | Proprietary (ST Programming Manual) | Cortex-M3 NVIC priority byte encoding, ISER/ICER/IP register interface, Handler mode entry/return. | 2026-09-03 |
| **ST Datasheet DS5319** | STMicroelectronics | Tier 1 (Silicon Spec) | DocID 13587 Rev 20 (31 Jul 2025) | Section 5.3.6 (Operating conditions), Section 5.3.11 (Timer characteristics) | Proprietary (ST Datasheet) | Maximum operating frequencies: SYSCLK 72 MHz, APB1 36 MHz, APB2 72 MHz. | 2026-09-03 |
| **Armv7-M Architecture Reference Manual** | Arm Limited | Tier 1 (Architectural Authority) | ARM DDI 0403E.e (Errata 2021) | Section B3.4 (NVIC), Section A3.5 (Memory barriers), Section B1.5 (Exception model) | Proprietary (Arm Architecture Spec) | Definitive architectural definition of hardware exception frame, EXC_RETURN codes, and DSB barrier behavior. | 2026-09-03 |
| **CMSIS_5** | Arm Limited | Tier 2 (Upstream Core Headers) | Tag `5.9.0` (commit `2b7495b8535bdcb306dac29b9ded4cfb679d7e5c`) | `CMSIS/Core/Include/core_cm3.h`, `cmsis_gcc.h` | Apache-2.0 (`LICENSE.CMSIS_5`) | `NVIC_SetPriority()`, `NVIC_EnableIRQ()`, `__DSB()`, `__WFI()`. | 2026-09-03 |
| **cmsis-device-f1** | STMicroelectronics | Tier 2 (Upstream Device Headers) | Tag `v4.3.5` (commit `8a76309ed1250d817e9c888c4417171d2ba3ba63`) | `Include/stm32f103xb.h` | Apache-2.0 (`LICENSE.cmsis-device-f1`) | Direct register structs: `RCC_TypeDef`, `GPIO_TypeDef`, `TIM_TypeDef`. | 2026-09-03 |
| **GNU LD Manual** | Free Software Foundation | Tier 1 (Toolchain Authority) | Binutils 2.42 Documentation | Section 3 (Linker Scripts: MEMORY, SECTIONS, PROVIDE, KEEP, ASSERT) | GNU FDL 1.3 | Formal semantics for memory region allocation, LMA vs VMA, section layout. | 2026-09-03 |
| **Arm GNU Toolchain Documentation** | Arm Limited / GCC | Tier 1 (Toolchain Authority) | Version 13.3.rel1 / GCC 13.2.1 | Manual: -nostartfiles, -O2, volatile semantics, disassembly listings | GNU GPLv3 / GCC Runtime Exception | C `volatile` load/store generation, startfile suppression, and optimization boundaries. | 2026-09-03 |

