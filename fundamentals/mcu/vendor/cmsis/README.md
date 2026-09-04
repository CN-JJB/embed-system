# Pinned CMSIS Dependencies

This directory contains the minimal set of authoritative, pinned CMSIS core and device headers required for bare-metal Cortex-M3 (STM32F103C8T6) development in Phase 2.

## Upstream Provenance

| Package | Organization | Tag / Version | Pinned Commit | Upstream Repository | License |
|---|---|---|---|---|---|
| **CMSIS_5** | Arm Limited | `5.9.0` | `2b7495b8535bdcb306dac29b9ded4cfb679d7e5c` | [ARM-software/CMSIS_5](https://github.com/ARM-software/CMSIS_5) | Apache-2.0 (`LICENSE.CMSIS_5`) |
| **cmsis-device-f1** | STMicroelectronics | `v4.3.5` | `8a76309ed1250d817e9c888c4417171d2ba3ba63` | [STMicroelectronics/cmsis-device-f1](https://github.com/STMicroelectronics/cmsis-device-f1) | Apache-2.0 (`LICENSE.cmsis-device-f1`) |

## File Inventory

- `include/core_cm3.h`: Cortex-M3 core peripheral access layer (`NVIC_SetPriority`, `NVIC_EnableIRQ`, `SCB` register definitions).
- `include/cmsis_version.h`: CMSIS version definitions.
- `include/cmsis_compiler.h`: Compiler agnostic definitions.
- `include/cmsis_gcc.h`: GNU C compiler specific inline functions (`__DSB`, `__ISB`, `__WFI`, etc.).
- `include/mpu_armv7.h`: MPU definitions for Armv7-M architecture.
- `include/stm32f1xx.h`: Top-level device selector header (`#define STM32F103xB`).
- `include/stm32f103xb.h`: STM32F103xB peripheral register memory maps, structure definitions (`RCC_TypeDef`, `GPIO_TypeDef`, `TIM_TypeDef`), bit masks, and interrupt vectors.
- `include/system_stm32f1xx.h`: Prototype declarations for system initialization (`SystemInit`).

## Redistribution & Policy Invariant

1. **No ST Ac6 Linker Script**: The vendor linker template (`STM32F103X8_FLASH.ld`) in vendor repositories carries an Ac6 non-redistribution notice and configures 128 KB Flash. It is **not** included here and must never be copied. Phase 2 utilizes an original pedagogical 64 KB linker script.
2. **License Notices Preserved**: The Apache-2.0 licenses from Arm Limited and STMicroelectronics are retained in full (`LICENSE.CMSIS_5` and `LICENSE.cmsis-device-f1`).
3. **Reproducibility**: The exact upstream git commit hashes are recorded above.
