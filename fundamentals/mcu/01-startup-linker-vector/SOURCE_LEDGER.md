# P2-M01 Source Ledger

This document registers the authoritative specifications, upstream source repositories, and tools establishing the technical baseline for Module P2-M01.

Repository canonical tier classification:
- **T0**: Specifications, datasheets, architecture references, and standards.
- **T1**: Upstream source code and pinned headers.
- **T2**: Official toolchain documentation and manuals.

| Upstream / Project | Organization | Canonical Tier | Exact Revision / Version / Commit | Exact File / Path / Section | License | Why Pedagogically Useful | Verification Status | Verification Date |
|---|---|---|---|---|---|---|---|---|
| **ST Reference Manual RM0008** | STMicroelectronics | T0 (Silicon Spec) | DocID 13902 Rev 21 (Feb 2021) | Section 3.3 (Embedded SRAM), Section 3.4 (Flash memory), Section 3.5 (Boot configuration) | Proprietary (ST Reference Manual) | Authoritative physical memory map, Flash latency table, and hardware boot aliasing rules. | VERIFIED (Manual inspection) | 2026-09-03 |
| **ST Programming Manual PM0056** | STMicroelectronics | T0 (Core Spec) | DocID 15491 Rev 7 (Dec 2024) | Section 2.1 (Processor modes and stacks), Section 2.2 (Memory model), Section 4.3 (NVIC) | Proprietary (ST Programming Manual) | Cortex-M3 processor programming model, initial MSP loading, register definitions. | VERIFIED (Manual inspection) | 2026-09-03 |
| **ST Datasheet DS5319** | STMicroelectronics | T0 (Silicon Spec) | DocID 13587 Rev 20 (31 Jul 2025) | Section 4 (Memory mapping), Section 5 (Electrical characteristics) | Proprietary (ST Datasheet) | Exact physical boundaries for STM32F103C8 (64 KB Flash, 20 KB SRAM). | VERIFIED (Manual inspection) | 2026-09-03 |
| **Armv7-M Architecture Reference Manual** | Arm Limited | T0 (Architecture Spec) | ARM DDI 0403E.e (Errata 2021) | Section B1.5.3 (Reset behavior), Section B1.5.1 (Exception model), Section A2.2 (Thumb state) | Proprietary (Arm Architecture Spec) | Definitive architectural definition of vector 0/1 fetch, Thumb bit requirement in PC, and reset state. | VERIFIED (Manual inspection) | 2026-09-03 |
| **CMSIS_5** | Arm Limited | T1 (Upstream Source) | Tag `5.9.0` (commit `2b7495b8535bdcb306dac29b9ded4cfb679d7e5c`) | `CMSIS/Core/Include/core_cm3.h`, `cmsis_gcc.h` | Apache-2.0 (`LICENSE.CMSIS_5`) | Standard Cortex-M3 register structs, SCB definitions, intrinsic barrier functions (`__DSB`). | VERIFIED (Header hash check) | 2026-09-03 |
| **cmsis-device-f1** | STMicroelectronics | T1 (Upstream Source) | Tag `v4.3.5` (commit `8a76309ed1250d817e9c888c4417171d2ba3ba63`) | `Include/stm32f103xb.h`, `system_stm32f1xx.h` | Apache-2.0 (`LICENSE.cmsis-device-f1`) | Authoritative STM32F103xB peripheral register layouts and bit definitions. | VERIFIED (Header hash check) | 2026-09-03 |
| **GNU LD Manual** | Free Software Foundation | T2 (Official Docs) | Binutils 2.42 Documentation | Section 3 (Linker Scripts: MEMORY, SECTIONS, PROVIDE, KEEP, ASSERT) | GNU FDL 1.3 | Syntax and formal semantics for memory region allocation, LMA vs VMA, constructor tables. | VERIFIED (Manual inspection) | 2026-09-03 |
| **Canonical Target Toolchain Baseline** | Arm Limited | T0/T2 (Target Baseline) | Arm GNU Toolchain 13.3.rel1 (GCC 13.3.1, Binutils 2.42, GDB 14.2) | Target cross-compilation baseline specification | GNU GPLv3 / GCC Runtime Exception | Canonical Phase 2 reference toolchain baseline. | PARTIALLY VERIFIED (Canonical binaries not executed on build host; build host uses Ubuntu 13.2.1 package) | 2026-09-04 |
| **Host Cross Toolchain Environment** | Ubuntu / Debian | T2 (Execution Host) | `arm-none-eabi-gcc` 13.2.1 20231009 (Ubuntu 15:13.2.rel1-2), GNU ld 2.42, GDB 15.1 | Package execution host | GNU GPLv3 / Binutils 2.42 | Alternate execution environment used for local compilation and static ELF inspection. | VERIFIED (Host compile/link/static tests) | 2026-09-04 |

## Provenance and Exclusion Notice

- **Original Linker Script:** The linker script [`linker/stm32f103c8tx_flash.ld`](linker/stm32f103c8tx_flash.ld) is an original pedagogical work written from GNU `ld` documentation and the STM32F103C8 memory specification.
- **Ac6 Vendor Linker Scripts Excluded:** Ac6 / System Workbench linker templates carry non-redistribution restrictions and define 128 KB Flash. They are strictly prohibited and not redistributed in this curriculum.
