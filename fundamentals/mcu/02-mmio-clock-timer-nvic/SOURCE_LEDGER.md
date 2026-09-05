# P2-M02 Source Ledger

This document registers the authoritative specifications, upstream source repositories, and tools establishing the technical baseline for Module P2-M02.

Repository canonical tier classification:
- **T0**: Specifications, datasheets, architecture references, and standards.
- **T1**: Upstream source code and pinned headers.
- **T2**: Official toolchain documentation and manuals.

| Upstream / Project | Organization | Canonical Tier | Exact Revision / Version / Commit | Exact File / Path / Section | License | Why Pedagogically Useful | Verification Status | Verification Date |
|---|---|---|---|---|---|---|---|---|
| **ST Reference Manual RM0008** | STMicroelectronics | T0 (Silicon Spec) | DocID 13902 Rev 21 (Feb 2021) | Section 3.3.3 (Flash latency), Section 6 (RCC), Section 9 (GPIO), Section 10 (Interrupts/NVIC), Section 14 (TIM2/3/4) | Proprietary (ST Reference Manual) | Authoritative clock tree diagram, APB1 prescaler timer doubling rule, BSRR/BRR atomic registers, TIM2 registers. | VERIFIED (Manual inspection) | 2026-09-03 |
| **ST Programming Manual PM0056** | STMicroelectronics | T0 (Core Spec) | DocID 15491 Rev 7 (Dec 2024) | Section 2.1 (Modes and stacks), Section 4.3 (NVIC), Section 4.4 (SCB) | Proprietary (ST Programming Manual) | Cortex-M3 NVIC priority byte encoding, ISER/ICER/IP register interface, Handler mode entry/return. | VERIFIED (Manual inspection) | 2026-09-03 |
| **ST Datasheet DS5319** | STMicroelectronics | T0 (Silicon Spec) | DocID 13587 Rev 20 (31 Jul 2025) | Section 5.3.6 (Operating conditions), Section 5.3.11 (Timer characteristics) | Proprietary (ST Datasheet) | Maximum operating frequencies: SYSCLK 72 MHz, APB1 36 MHz, APB2 72 MHz. | VERIFIED (Manual inspection) | 2026-09-03 |
| **Armv7-M Architecture Reference Manual** | Arm Limited | T0 (Architecture Spec) | ARM DDI 0403E.e (Errata 2021) | Section B3.4 (NVIC), Section A3.5 (Memory barriers), Section B1.5 (Exception model) | Proprietary (Arm Architecture Spec) | Definitive architectural definition of hardware exception frame, EXC_RETURN codes, and DSB barrier behavior. | VERIFIED (Manual inspection) | 2026-09-03 |
| **CMSIS_5** | Arm Limited | T1 (Upstream Source) | Tag `5.9.0` (commit `2b7495b8535bdcb306dac29b9ded4cfb679d7e5c`) | `CMSIS/Core/Include/core_cm3.h`, `cmsis_gcc.h` | Apache-2.0 (`LICENSE.CMSIS_5`) | `NVIC_SetPriority()`, `NVIC_EnableIRQ()`, `__DSB()`, `__WFI()`. | VERIFIED (Header hash check) | 2026-09-03 |
| **cmsis-device-f1** | STMicroelectronics | T1 (Upstream Source) | Tag `v4.3.5` (commit `8a76309ed1250d817e9c888c4417171d2ba3ba63`) | `Include/stm32f103xb.h` | Apache-2.0 (`LICENSE.cmsis-device-f1`) | Direct register structs: `RCC_TypeDef`, `GPIO_TypeDef`, `TIM_TypeDef`. | VERIFIED (Header hash check) | 2026-09-03 |
| **GNU LD Manual** | Free Software Foundation | T2 (Official Docs) | Binutils 2.42 Documentation | Section 3 (Linker Scripts: MEMORY, SECTIONS, PROVIDE, KEEP, ASSERT) | GNU FDL 1.3 | Formal semantics for memory region allocation, LMA vs VMA, section layout. | VERIFIED (Manual inspection) | 2026-09-03 |
| **Canonical Target Toolchain Baseline** | Arm Limited | T2 (Official Tooling) | Arm GNU Toolchain 13.3.rel1 (GCC 13.3.1, Binutils 2.42, GDB 14.2, Newlib 4.4.0) | Official release/toolchain documentation | Multi-component distribution; preserve upstream component license notices | Canonical Phase 2 reference toolchain baseline. | PARTIALLY VERIFIED (canonical binaries not executed on build host; build host uses Ubuntu 13.2.1 package) | 2026-09-04 |
| **Host Cross Toolchain Environment** | Ubuntu / Debian | T2 (Execution Host) | `arm-none-eabi-gcc` 13.2.1 20231009 (Ubuntu 15:13.2.rel1-2), GNU ld 2.42, GDB 15.1, Newlib 4.4.0 package | Ubuntu package execution host | Multi-component distribution; preserve package/upstream license notices | Alternate execution environment used for local compilation and static ELF inspection. | VERIFIED (host compile/link/static tests) | 2026-09-04 |
