# Phase 2 M03 and M04 Implementation & Verification Notes

> Status: **Author Implementation Complete — Ready for Leader Review**  
> Author: Antigravity Subsystem Engineer  
> Date: **2026-09-05**  
> Baseline Reference: Issue #18, `roadmap/phase-2-stm32-freertos.md`, `research/phase-2/2026-09-03-stm32-freertos-curriculum-design.md`, PR #17 (M01+M02 canonical merge)  
> Target Branch: `tutorial/p2-m03-m04`  
> Scope Implemented: **P2-M03 (4.5 h MUST) + P2-M04 (5.0 h MUST) = strictly 9.5 h MUST**

---

## 1. Scope Boundary Enforcement

- [x] Implemented **only** P2-M03 and P2-M04.
- [x] Strict **9.5 h MUST** load preserved:
  - **P2-M03**: 4.5 h MUST (Labs 01–06, Faults f1–f5, Challenge, Gate).
  - **P2-M04**: 5.0 h MUST (Labs 01–05, Faults f1–f5, Challenge, Gate).
- [x] **NO** P2-M05 queue / `FromISR` pipeline prematurely implemented.
- [x] **NO** P2-M06 priority inversion or mutexes.
- [x] **NO** P2-M07 integration task or multi-sensor pipeline.
- [x] Upstream FreeRTOS strictly pinned to commit `9b777ae5c5b8e9e456065a00294d1e5f5f9facf5` (Tag `V11.3.0`).
- [x] Reviewer isolation maintained: solutions, mutations, and regression scripts reside in `reviewer/` subdirectories; student-facing material contains no answers.
- [x] Honesty disclosure: all builds, ELF symbols, disassembled instructions, and mutation regressions are **VERIFIED** on host; physical hardware pins, live waveforms, and GDB interactive steps are explicitly marked **UNVERIFIED**.

---

## 2. Execution Environment & Toolchain Identity

### Canonical Target Toolchain Baseline
- **Specification**: Arm GNU Toolchain 13.3.rel1
- **Expected Components**: GCC 13.3.1, GNU Binutils 2.42, GDB 14.2, Newlib 4.4.0
- **Status**: **PARTIALLY VERIFIED** (Target contracts, compiler flags `-mcpu=cortex-m3 -mthumb`, and Binutils 2.42 linker scripts verified; cross-compiled via Ubuntu package on host).

### Actual Test Host Execution Environment
- **Host System**: Linux 6.6.87.1 / Ubuntu 24.04.1 LTS on WSL2 (Windows 11)
- **C Cross-Compiler**: `arm-none-eabi-gcc (Ubuntu 15:13.2.rel1-2) 13.2.1 20231009`
- **Linker / Binary Utilities**: `GNU ld (2.42-1ubuntu1+23) 2.42`, `arm-none-eabi-objdump`, `arm-none-eabi-nm`, `arm-none-eabi-size`
- **C Library**: `Newlib 4.4.0 (libnewlib-arm-none-eabi 4.4.0.20231231-2)`
- **Build System**: GNU Make 4.3
- **Status**: **VERIFIED** for all compile, link, disassembly, memory budget, and negative mutation runs.

---

## 3. Authoritative Upstream Sources & Source Ledger

| Tier | Resource | Pinned Revision / Tag / Commit | Role |
| :--- | :--- | :--- | :--- |
| **T0** | ST RM0008 Reference Manual | Rev 21 (Feb 2021) | STM32F103 peripherals: TIM3, ADC1, DMA1, RCC, NVIC |
| **T0** | ST PM0056 Programming Manual | Rev 7 (Dec 2024) | Cortex-M3 core, SysTick, SHPR, BASEPRI, SCB |
| **T0** | ST DS5319 Datasheet | Rev 20 (Jul 2025) | STM32F103 electrical characteristics, $R_{\text{AIN}}$, $f_{\text{ADC}}$ |
| **T0** | Arm DDI 0403E.e (v7-M Arch Ref) | ARMv7-M Architecture Reference | Exception stack frame, Thumb bit, unstacking rules |
| **T1** | FreeRTOS Kernel Upstream | `V11.3.0` (`9b777ae5c5b8e9e456065a00294d1e5f5f9facf5`) | RTOS scheduler, tasks.c, list.c, heap_4.c, port.c |
| **T1** | ARM CMSIS_5 | `5.9.0` (`2b7495b8535bdcb306dac29b9ded4cfb679d7e5c`) | Core Cortex-M register and intrinsic definitions |
| **T1** | ST cmsis-device-f1 | `v4.3.5` (`8a76309ed1250d817e9c888c4417171d2ba3ba63`) | STM32F103 register headers and memory map |
| **T2** | FreeRTOS Reference Manual | V10.0.0 / V11.0 Guide | Kernel architecture, API contracts, licensing |

---

## 4. Module P2-M03 Implementation Audit

### Autonomous Hardware Acquisition Pipeline
```text
TIM3 Update @ 10 kHz
  ──► TIM3 TRGO (CR2.MMS = 010)
  ──► ADC1 External Trigger (CR2.EXTSEL = 100, EXTTRIG = 1)
  ──► 55.5 cycles sample time on PA0 (SMPR2.SMP0 = 101, ADCPRE = /6 -> 12 MHz)
  ──► ADC1 DMA Request
  ──► DMA1 Channel 1 Circular Transfer (CPAR = &ADC1->DR, CMAR = g_adc_buffer, CNDTR = 128)
  ──► Persistent SRAM Buffer (128 samples * 2 bytes = 256 bytes)
  ──► Half-Transfer (HT) ISR (Sample 63) -> Toggle PA3 (Pulse repetition: 78.125 Hz)
  ──► Transfer-Complete (TC) ISR (Sample 127) -> Toggle PA4 (Pulse repetition: 78.125 Hz)
  ──► CPU remains in __WFI() with zero per-sample interrupt overhead
```

### Static Resource Footprint
- **Flash Usage**: 1,788 bytes ($\approx 2.7\%$ of 64 KB limit) — **VERIFIED**
- **SRAM Usage**: 1,296 bytes ($\approx 6.3\%$ of 20 KB limit) — **VERIFIED**
- **Circular Buffer**: 256 bytes (`g_adc_buffer[128]`) placed in `.bss` — **VERIFIED**
- **HAL/CubeMX Code**: 0 bytes linked — **VERIFIED**

### Pedagogical Assessment & Reviewer Fixtures
- **Labs**: 6 structured labs (01 Clock/Prescaler, 02 Calibration/Sequence, 03 TIM3 TRGO, 04 DMA1 Circular, 05 HT/TC Milestones, 06 Fault Investigation).
- **Controlled Faults**: `f1` (ADCPRE out-of-spec), `f2` (trigger routing misconfiguration), `f3` (DMA transfer-width mismatch), `f4` (DMA buffer lifetime violation), `f5` (ADC DMA-request enable omitted).
- **Challenge & Validator**: `challenge/acquisition.c`, `challenge/validate.sh`.
- **Reviewer Suite**: 8 negative mutations in `reviewer/mutations/` (`test_m03_validator_mutations.sh` 8/8 rejected).
- **Module Gate**: Seeded hardware defect `TIM_CR1_UDIS` blocking TRGO events. Verified by `reviewer/verify_gate_regression.sh`.

---

## 5. Module P2-M04 Implementation Audit

### FreeRTOS Kernel Core & Context Switch Architecture
- **Upstream Pinning**: FreeRTOS V11.3.0 pinned and vendored directly under `fundamentals/rtos/vendor/freertos/`.
- **Vector Table Remapping**:
  ```c
  #define vPortSVCHandler     SVC_Handler     /* Vector 11 (0x2C) */
  #define xPortPendSVHandler  PendSV_Handler  /* Vector 14 (0x38) */
  #define xPortSysTickHandler SysTick_Handler /* Vector 15 (0x3C) */
  ```
  Ensures vector entries resolve to `port.c` rather than `Default_Handler` infinite loops.
- **Dynamic Clock Coherence**:
  `#define configCPU_CLOCK_HZ (SystemCoreClock)` dynamically tracks 72 MHz HSE or 64 MHz HSI fallback, preventing 12.5% timing dilation.
- **Dual Stack Architecture**:
  - MSP: Kernel and ISRs (`0x20005000` downward).
  - PSP: FreeRTOS tasks in Thread mode.
  - Initial synthetic stack frame initializes bit 24 of `xPSR` to 1 (`portINITIAL_XPSR = 0x01000000`), avoiding Cortex-M `INVSTATE` UsageFaults.
- **Context Switch Mechanics**:
  - `portSAVE_CONTEXT`: `mrs r0, psp`, `stmdb r0!, {r4-r11}`, `str r0, [pxCurrentTCB]`.
  - `vTaskSwitchContext`: Protected by `msr basepri, #0x50`.
  - `portRESTORE_CONTEXT`: `ldr r0, [pxCurrentTCB]`, `ldmia r0!, {r4-r11}`, `msr psp, r0`, `bx lr` (`0xFFFFFFFD`).
- **Memory Management**:
  - `heap_4.c` with 8-byte alignment, first-fit scanning, and contiguous block coalescing.
  - `configTOTAL_HEAP_SIZE = 10 KB` (`10240` bytes).
  - Zero libc `malloc` or `free` linked.

### Static Resource Footprint
- **Flash Usage**: 5,204 bytes ($\approx 7.9\%$ of 64 KB limit) — **VERIFIED**
- **SRAM Usage**: 11,576 bytes ($\approx 56.5\%$ of 20 KB limit, including 10 KB FreeRTOS heap) — **VERIFIED**
- **Heap Size**: 10,240 bytes (`ucHeap`) in `.bss` — **VERIFIED**
- **HAL/CubeMX/CMSIS-RTOS Wrappers**: 0 bytes linked — **VERIFIED**

### Pedagogical Assessment & Reviewer Fixtures
- **Labs**: 5 structured labs (01 Kernel Integration, 02 Clock/SysTick Coherence, 03 Task Creation/Preemption, 04 PendSV Assembly, 05 `heap_4` SRAM Budget).
- **Controlled Faults**:
  - `f1`: Vector table points to `Default_Handler` for FreeRTOS exceptions.
  - `f2`: Static clock mismatch (72 MHz assumed under 64 MHz HSI).
  - `f3`: Undersized stack (16 words, immediate overflow).
  - `f4`: Initial xPSR missing Thumb bit (`INVSTATE` UsageFault).
  - `f5`: Heap exhaustion (`configTOTAL_HEAP_SIZE = 512 B`).
- **Challenge & Validator**: `challenge/app_tasks.c`, `challenge/validate.sh`.
- **Reviewer Suite**: 8 negative mutations in `reviewer/mutations/` (`test_m04_validator_mutations.sh` 8/8 rejected).
- **Module Gate**: Seeded unshifted `configMAX_SYSCALL_INTERRUPT_PRIORITY = 5` defect (causes `BASEPRI = 0`, unmasking critical sections). Verified by `reviewer/verify_gate_regression.sh`.

---

## 6. Verification Evidence Matrix

| Check Description | Target / File | Method | Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **M03 Firmware Build** | `03-adc-dma-acquisition/build/firmware.elf` | `make -C fundamentals/mcu/03-adc-dma-acquisition clean all` | Clean build, 0 warnings | **VERIFIED** |
| **M03 Memory Bounds** | `03-adc-dma-acquisition/build/firmware.elf` | `arm-none-eabi-size` | Flash: 1788 B, RAM: 1296 B | **VERIFIED** |
| **M03 Zero HAL** | `03-adc-dma-acquisition/` | `grep -rql "HAL_Init"` | 0 matches | **VERIFIED** |
| **M03 Hardware Registers** | `03-adc-dma-acquisition/build/firmware.elf` | `arm-none-eabi-objdump -d` | ADC1->CR2, TIM3->CR2, DMA1->IFCR | **VERIFIED** |
| **M03 Automated Harness** | `03-adc-dma-acquisition/scripts/verify_m03.sh` | Bash automated runner | All static checks passed | **VERIFIED** |
| **M03 Faults f1–f5** | `03-adc-dma-acquisition/faults/f1..f5` | `make clean all` | All 5 compile cleanly with -Werror | **VERIFIED** |
| **M03 Mutations 1–8** | `03-adc-dma-acquisition/reviewer/mutations/` | `test_m03_validator_mutations.sh` | 8/8 correctly rejected | **VERIFIED** |
| **M03 Gate Regression** | `03-adc-dma-acquisition/reviewer/verify_gate_regression.sh` | Automated regression test | Defect detected, patch verified | **VERIFIED** |
| **M04 Firmware Build** | `01-freertos-scheduler-context-switch/build/firmware.elf` | `make -C fundamentals/rtos/01-freertos-scheduler-context-switch clean all` | Clean build, 0 warnings | **VERIFIED** |
| **M04 Memory Bounds** | `01-freertos-scheduler-context-switch/build/firmware.elf` | `arm-none-eabi-size` | Flash: 5204 B, RAM: 11576 B | **VERIFIED** |
| **M04 FreeRTOS Symbols** | `01-freertos-scheduler-context-switch/build/firmware.elf` | `arm-none-eabi-nm` | vTaskStartScheduler, PendSV_Handler, ucHeap | **VERIFIED** |
| **M04 Vector Remapping** | `01-freertos-scheduler-context-switch/build/firmware.elf` | `arm-none-eabi-nm` | SVC, PendSV, SysTick != Default_Handler | **VERIFIED** |
| **M04 Libc Malloc Absence** | `01-freertos-scheduler-context-switch/build/firmware.elf` | `arm-none-eabi-nm` | malloc, _malloc_r absent | **VERIFIED** |
| **M04 Automated Harness** | `01-freertos-scheduler-context-switch/scripts/verify_m04.sh` | Bash automated runner | All static checks passed | **VERIFIED** |
| **M04 Faults f1–f5** | `01-freertos-scheduler-context-switch/faults/f1..f5` | `make clean all` | All 5 compile cleanly with -Werror | **VERIFIED** |
| **M04 Mutations 1–8** | `01-freertos-scheduler-context-switch/reviewer/mutations/` | `test_m04_validator_mutations.sh` | 8/8 correctly rejected | **VERIFIED** |
| **M04 Gate Regression** | `01-freertos-scheduler-context-switch/reviewer/verify_gate_regression.sh` | Automated regression test | Defect detected, patch verified | **VERIFIED** |
| **Top-Level MCU Base Check** | `fundamentals/mcu/Makefile` | `make -C fundamentals/mcu check` | M01, M02, M03 base module static checks passed | **VERIFIED** |
| **Top-Level RTOS Base Check** | `fundamentals/rtos/Makefile` | `make -C fundamentals/rtos check` | M04 base module static checks passed | **VERIFIED** |
| **Live Hardware Signals** | STM32F103 Pins PA0, PA1, PA2, PA3, PA4, PC13 | Oscilloscope / Logic Analyzer | No physical hardware connected | **UNVERIFIED** |
| **Live GDB Step Debugging** | Cortex-M3 Core Registers (R0-R15, xPSR, PSP) | OpenOCD / ST-Link | Headless build container | **UNVERIFIED** |

---

## 7. Cross-Module Pedagogical Bridge

Modules P2-M03 and P2-M04 establish the two foundational pillars of real-time embedded systems:
1. **Autonomous Hardware Data Acquisition (P2-M03)**:
   Teaches how peripheral timers, ADCs, and DMA channels move analog data into memory autonomously without CPU intervention.
2. **Deterministic Task Preemption and Context Switching (P2-M04)**:
   Teaches how the CPU multiplexes execution threads, tracks timebases, and guarantees deterministic task response times.

In the upcoming **P2-M05**, these two pillars converge:
The DMA Half-Transfer and Transfer-Complete interrupt service routines engineered in M03 will post buffers into FreeRTOS Queues using `xQueueSendFromISR()`, notifying worker tasks unblocked via FreeRTOS synchronization primitives.
By isolating M03 and M04 in this milestone, learners achieve deep, uncompromised mastery of each layer before integrating them.
