# P2-M01 Source Ledger

This document registers the authoritative specifications, upstream source repositories, and tools establishing the technical baseline for Module P2-M01.

| Upstream / Project | Organization | Tier | Exact Revision / Version / Commit | Exact File / Path / Section | License | Why Pedagogically Useful | Verification Date |
|---|---|---|---|---|---|---|---|
| **ST Reference Manual RM0008** | STMicroelectronics | Tier 1 (Primary Vendor Spec) | DocID 13902 Rev 21 (Feb 2021) | Section 3.3 (Embedded SRAM), Section 3.4 (Flash memory), Section 3.5 (Boot configuration) | Proprietary (ST Reference Manual) | Authoritative physical memory map, Flash latency table, and hardware boot aliasing rules. | 2026-09-03 |
| **ST Programming Manual PM0056** | STMicroelectronics | Tier 1 (Core Programming Model) | DocID 15491 Rev 7 (Dec 2024) | Section 2.1 (Processor modes and stacks), Section 2.2 (Memory model), Section 4.3 (NVIC) | Proprietary (ST Programming Manual) | Cortex-M3 processor programming model, initial MSP loading, register definitions. | 2026-09-03 |
| **ST Datasheet DS5319** | STMicroelectronics | Tier 1 (Electrical / Silicon Spec) | DocID 13587 Rev 20 (31 Jul 2025) | Section 4 (Memory mapping), Section 5 (Electrical characteristics) | Proprietary (ST Datasheet) | Exact physical boundaries for STM32F103C8 (64 KB Flash, 20 KB SRAM). | 2026-09-03 |
| **Armv7-M Architecture Reference Manual** | Arm Limited | Tier 1 (Architectural Authority) | ARM DDI 0403E.e (Errata 2021) | Section B1.5.3 (Reset behavior), Section B1.5.1 (Exception model), Section A2.2 (Thumb state) | Proprietary (Arm Architecture Spec) | Definitive architectural definition of vector 0/1 fetch, Thumb bit requirement in PC, and reset state. | 2026-09-03 |
| **CMSIS_5** | Arm Limited | Tier 2 (Upstream Core Headers) | Tag `5.9.0` (commit `2b7495b8535bdcb306dac29b9ded4cfb679d7e5c`) | `CMSIS/Core/Include/core_cm3.h`, `cmsis_gcc.h` | Apache-2.0 (`LICENSE.CMSIS_5`) | Standard Cortex-M3 register structs, SCB definitions, intrinsic barrier functions (`__DSB`). | 2026-09-03 |
| **cmsis-device-f1** | STMicroelectronics | Tier 2 (Upstream Device Headers) | Tag `v4.3.5` (commit `8a76309ed1250d817e9c888c4417171d2ba3ba63`) | `Include/stm32f103xb.h`, `system_stm32f1xx.h` | Apache-2.0 (`LICENSE.cmsis-device-f1`) | Authoritative STM32F103xB peripheral register layouts and bit definitions. | 2026-09-03 |
| **GNU LD Manual** | Free Software Foundation | Tier 1 (Toolchain Authority) | Binutils 2.42 Documentation | Section 3 (Linker Scripts: MEMORY, SECTIONS, PROVIDE, KEEP, ASSERT) | GNU FDL 1.3 | Syntax and formal semantics for memory region allocation, LMA vs VMA, constructor tables. | 2026-09-03 |
| **Arm GNU Toolchain Documentation** | Arm Limited / GCC | Tier 1 (Toolchain Authority) | Version 13.3.rel1 / GCC 13.2.1 | Manual options `-nostartfiles`, `-Wl,-e`, `--specs=nano.specs` | GNU GPLv3 / GCC Runtime Exception | Standard compiler and linker driver contracts for bare-metal startfile suppression. | 2026-09-03 |

## Provenance and Exclusion Notice

- **Original Linker Script:** The linker script [`linker/stm32f103c8tx_flash.ld`](linker/stm32f103c8tx_flash.ld) is an original pedagogical work written from GNU `ld` documentation and the STM32F103C8 memory specification.
- **Ac6 Vendor Linker Scripts Excluded:** Ac6 / System Workbench linker templates carry non-redistribution restrictions and define 128 KB Flash. They are strictly prohibited and not redistributed in this curriculum.
