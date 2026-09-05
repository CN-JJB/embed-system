# Source Ledger: P2-M06 FreeRTOS Priority Inversion, Priority Inheritance, Stack Watermark & Watchdog

> Mandatory provenance record according to root `AGENTS.md` and Issue #21.  
> Target Silicon: **STM32F103C8T6** (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM)  
> Last Verified: **2026-09-05**

---

## 1. Upstream Source Ledger

| Tier | Organization | Resource | Exact Revision / Tag / Commit | Exact Path / Function / Chapter | License | Pedagogical Reason | Verification Date |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **T0** | STMicroelectronics | RM0008 Reference Manual | DocID 13902 Rev 21 (Feb 2021) | Section 18 (Independent Watchdog - IWDG: KR, PR, RLR, SR), Section 6.3.10 (RCC CSR: IWDGRSTF, RMVF) | ST Proprietary (Evaluation) | Authoritative IWDG register specifications, key register unlock sequences (0x5555, 0xCCCC, 0xAAAA), prescaler/reload timing formulas, and reset cause flag handling | 2026-09-05 |
| **T0** | STMicroelectronics | PM0056 Programming Manual | DocID 15491 Rev 7 (Dec 2024) | Section 2.1 (Stack memory: Full descending stack, MSP, PSP), Section 4.3 (NVIC: System Handler Priority Registers) | ST Proprietary (Evaluation) | Cortex-M3 full descending stack mechanics, memory boundaries, and exception stack frames | 2026-09-05 |
| **T0** | Arm Limited | Armv7-M Architecture Reference Manual | ARM DDI 0403E.e | Section B1.5 (Exception model, stack alignment, double-word 8-byte alignment rule) | Arm Proprietary | Architectural stack alignment constraints and exception handling guarantees | 2026-09-05 |
| **T1** | FreeRTOS / Amazon AWS | FreeRTOS-Kernel Upstream | `V11.3.0` (`9b777ae5c5b8e9e456065a00294d1e5f5f9facf5`) | `tasks.c` (`xTaskPriorityInherit()`, `xTaskPriorityDisinherit()`, `uxTaskGetStackHighWaterMark()`) | MIT | Exact kernel mechanisms for mutex owner priority boosting, restoration, and high watermark calculation via 0xA5 fill pattern scanning | 2026-09-05 |
| **T1** | FreeRTOS / Amazon AWS | FreeRTOS-Kernel Upstream | `V11.3.0` (`9b777ae5c5b8e9e456065a00294d1e5f5f9facf5`) | `queue.c` (`xQueueCreateMutex()`, `xQueueSemaphoreTake()`, `prvCopyDataFromQueue()`) | MIT | Authoritative mutex queue type (`queueQUEUE_TYPE_MUTEX`), recursive holder tracking (`pxMutexHolder`), and disinherit triggers on release | 2026-09-05 |
| **T1** | FreeRTOS / Amazon AWS | FreeRTOS-Kernel Upstream | `V11.3.0` (`9b777ae5c5b8e9e456065a00294d1e5f5f9facf5`) | `include/stack_macros.h` (`taskCHECK_FOR_STACK_OVERFLOW()`) | MIT | Kernel runtime stack overflow detection: Method 1 (SP boundary check) and Method 2 (end-of-stack 16-byte 0xA5 boundary check) | 2026-09-05 |
| **T1** | Arm Limited | CMSIS_5 | `5.9.0` (`2b7495b8535bdcb306dac29b9ded4cfb679d7e5c`) | `CMSIS/Core/Include/core_cm3.h` | Apache-2.0 | Standard Cortex-M3 register definitions and compiler barrier intrinsics | 2026-09-05 |
| **T1** | STMicroelectronics | cmsis-device-f1 | `v4.3.5` (`8a76309ed1250d817e9c888c4417171d2ba3ba63`) | `Include/stm32f103xb.h` (IWDG, RCC_CSR, GPIO register definitions) | Apache-2.0 | MMIO register layout for STM32F103 IWDG and reset control registers | 2026-09-05 |
| **T2** | FreeRTOS / Amazon AWS | Mastering the FreeRTOS Real Time Kernel | V10.0.0 / V11.0 Reference Guide | Chapter 8 (Resource Management: Priority Inversion, Priority Inheritance, Deadlock), Chapter 12 (Troubleshooting: Stack Overflow Detection) | CC-BY-ND 3.0 | Canonical explanation of priority inversion pathology, priority inheritance limitations (deadlock non-prevention), and stack watermark units | 2026-09-05 |

---

## 2. Integrity and Licensing Attestation

- FreeRTOS sources retain official MIT license headers (`LICENSE.md` under `fundamentals/rtos/vendor/freertos/`).
- CMSIS device headers retain Apache-2.0 notices under `fundamentals/mcu/vendor/cmsis/include/`.
- No proprietary HAL, STM32Cube, or closed-source RTOS wrappers are utilized.
- Canonical baseline: **Arm GNU Toolchain 13.3.rel1** (GCC 13.3.1 / Binutils 2.42 / GDB 14.2 / Newlib 4.4.0). Actual host verification for this implementation used Ubuntu/WSL `arm-none-eabi-gcc` **13.2.1** with Binutils **2.42**; canonical 13.3.rel1 execution remains separate from those host results.
