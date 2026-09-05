# Source Ledger: P2-M05 FreeRTOS Queue, Mutex, and ISR-Safe Synchronization Boundaries

> Mandatory provenance record according to root `AGENTS.md` and Issue #21.  
> Target Silicon: **STM32F103C8T6** (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM)  
> Last Verified: **2026-09-05**

---

## 1. Upstream Source Ledger

| Tier | Organization | Resource | Exact Revision / Tag / Commit | Exact Path / Function / Chapter | License | Pedagogical Reason | Verification Date |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **T0** | STMicroelectronics | PM0056 Programming Manual | DocID 15491 Rev 7 (Dec 2024) | Section 2.2 (Core Registers: BASEPRI, PRIMASK), Section 4.3 (NVIC: IPR, AIRCR) | ST Proprietary (Evaluation) | Authoritative hardware exception model, priority grouping (PRIGROUP), and interrupt masking behavior | 2026-09-05 |
| **T0** | STMicroelectronics | RM0008 Reference Manual | DocID 13902 Rev 21 (Feb 2021) | Section 10 (Interrupts & Events), Section 15 (TIM2 to TIM5 general-purpose timers) | ST Proprietary (Evaluation) | TIM2 peripheral clocking, prescaler/reload math, and update interrupt flag clearing contracts | 2026-09-05 |
| **T0** | Arm Limited | Armv7-M Architecture Reference Manual | ARM DDI 0403E.e | Section B1.5 (Exception model), Section B3.2 (System Control Space & SCB->ICSR PENDSVSET) | Arm Proprietary | Architectural exception priority rules, tail-chaining invariants, and PendSV trigger mechanics | 2026-09-05 |
| **T1** | FreeRTOS / Amazon AWS | FreeRTOS-Kernel Upstream | `V11.3.0` (`9b777ae5c5b8e9e456065a00294d1e5f5f9facf5`) | `queue.c` (`xQueueGenericSendFromISR()`, `xQueueReceive()`, `xQueueGenericCreate()`) | MIT | Authoritative queue storage, copy-by-value (`memcpy`), and wait-list wake mechanics | 2026-09-05 |
| **T1** | FreeRTOS / Amazon AWS | FreeRTOS-Kernel Upstream | `V11.3.0` (`9b777ae5c5b8e9e456065a00294d1e5f5f9facf5`) | `tasks.c` (`xTaskRemoveFromEventList()`) | MIT | Exact V11.3.0 single-core unblocking semantics: strict `>` priority comparison and `xPendingReadyList` path | 2026-09-05 |
| **T1** | FreeRTOS / Amazon AWS | FreeRTOS-Kernel Upstream | `V11.3.0` (`9b777ae5c5b8e9e456065a00294d1e5f5f9facf5`) | `portable/GCC/ARM_CM3/port.c` (`vPortValidateInterruptPriority()`) | MIT | Cortex-M3 runtime assertion inspecting ISR priority byte against `ucMaxSysCallPriority` and AIRCR grouping | 2026-09-05 |
| **T1** | FreeRTOS / Amazon AWS | FreeRTOS-Kernel Upstream | `V11.3.0` (`9b777ae5c5b8e9e456065a00294d1e5f5f9facf5`) | `portable/GCC/ARM_CM3/portmacro.h` (`portYIELD_FROM_ISR()`, `portSET_INTERRUPT_MASK_FROM_ISR()`) | MIT | BASEPRI manipulation and asynchronous PendSV trigger via `portNVIC_INT_CTRL_REG |= portNVIC_PENDSVSET_BIT` | 2026-09-05 |
| **T1** | Arm Limited | CMSIS_5 | `5.9.0` (`2b7495b8535bdcb306dac29b9ded4cfb679d7e5c`) | `CMSIS/Core/Include/core_cm3.h` (`NVIC_SetPriority()`, `NVIC_SetPriorityGrouping()`) | Apache-2.0 | Standard Cortex-M CMSIS hardware abstractions and priority shifting macros | 2026-09-05 |
| **T1** | STMicroelectronics | cmsis-device-f1 | `v4.3.5` (`8a76309ed1250d817e9c888c4417171d2ba3ba63`) | `Include/stm32f103xb.h` (TIM2, RCC, GPIO register definitions) | Apache-2.0 | Memory-mapped register definitions and peripheral bitfields for STM32F103 | 2026-09-05 |
| **T2** | FreeRTOS / Amazon AWS | Mastering the FreeRTOS Real Time Kernel | V10.0.0 / V11.0 Reference Guide | Chapter 4 (Queue Management), Chapter 7 (Interrupt Management) | CC-BY-ND 3.0 | Pedagogical explanation of queue ownership, ISR safety rules, and deferred interrupt handling | 2026-09-05 |

---

## 2. Integrity and Licensing Attestation

- FreeRTOS sources retain official MIT license headers (`LICENSE.md` under `fundamentals/rtos/vendor/freertos/`).
- CMSIS device headers retain Apache-2.0 notices under `fundamentals/mcu/vendor/cmsis/include/`.
- No proprietary HAL, STM32Cube, or closed-source RTOS wrappers are utilized.
- All code compiles under strict `-Wall -Wextra -Werror` with Arm GNU Toolchain 13.3.rel1 / Ubuntu GCC 13.2.1 cross-compiler.
