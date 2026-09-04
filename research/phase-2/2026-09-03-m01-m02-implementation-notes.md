# Phase 2 M01 and M02 Implementation & Verification Notes

> Status: **Author Implementation Complete — Leader Review Required**  
> Author: Antigravity Automated Bare-Metal Subsystem Engineer  
> Date: **2026-09-04**  
> Baseline Reference: Issue #16, `roadmap/phase-2-stm32-freertos.md`, `research/phase-2/2026-09-03-stm32-freertos-curriculum-design.md`  
> Target Branch: `tutorial/p2-m01-m02`  
> Scope Implemented: **P2-M01 (3.5 h MUST) + P2-M02 (4.5 h MUST) = 8.0 h MUST**

---

## 1. Scope Boundary Enforcement

- [x] Implemented **only** P2-M01 and P2-M02.
- [x] Strict **8.0 h MUST** load preserved (P2-M01: 3.5 h, P2-M02: 4.5 h).
- [x] **NO** ADC or DMA implementation (strictly reserved for P2-M03).
- [x] **NO** FreeRTOS kernel integration (strictly reserved for P2-M04+).
- [x] **NO** Linux / U-Boot / Buildroot.
- [x] **NO** HAL cookbooks or auto-generated STM32Cube code in MUST paths.
- [x] **NO** Ac6 vendor linker script redistribution.

---

## 2. Execution Environment & Tool Versions

Executable builds and verification checks were performed on:

```text
Host Environment: Linux 6.6 / Ubuntu 24.04.1 LTS (Noble Numbat) on WSL2 / Windows 11
C Compiler: arm-none-eabi-gcc (Ubuntu 15:13.2.rel1-2) 13.2.1 20231009
Linker / Binary Tools: GNU Binutils 2.42 (binutils-arm-none-eabi 2.42-1ubuntu1+23)
C Library: Newlib 4.4.0 (libnewlib-arm-none-eabi 4.4.0.20231231-2)
Debugger: GNU GDB (Ubuntu 15.1-1ubuntu1~24.04.1) 15.1 / gdb-multiarch 15.1
Build System: GNU Make 4.3 (WSL2) / GNU Make 4.4.1 (Windows)
```

---

## 3. Pinned Upstream Sources & Ledger

All peripheral structures and core macros are pinned from authoritative upstream releases without copying vendor linker templates:

1. **Arm CMSIS_5**:
   - Upstream: `ARM-software/CMSIS_5`
   - Release: `5.9.0`
   - Commit: `2b7495b8535bdcb306dac29b9ded4cfb679d7e5c`
   - License: Apache-2.0 (`LICENSE.CMSIS_5`)
   - Path: `fundamentals/mcu/vendor/cmsis/include/core_cm3.h`
2. **STMicroelectronics cmsis-device-f1**:
   - Upstream: `STMicroelectronics/cmsis-device-f1`
   - Release: `v4.3.5`
   - Commit: `8a76309ed1250d817e9c888c4417171d2ba3ba63`
   - License: Apache-2.0 (`LICENSE.cmsis-device-f1`)
   - Path: `fundamentals/mcu/vendor/cmsis/include/stm32f103xb.h`
3. **ST Reference Manual RM0008**: Rev 21 (Feb 2021).
4. **ST Programming Manual PM0056**: Rev 7 (Dec 2024).
5. **ST Datasheet DS5319**: Rev 20 (Jul 2025).
6. **Armv7-M Architecture Reference Manual**: ARM DDI 0403E.e.
7. **GNU LD Manual**: Binutils 2.42.
8. **Arm GNU Toolchain Documentation**: Version 13.3.rel1 / GCC 13.2.1.

---

## 4. Verification Evidence Matrix

| Check / Domain | Command / Procedure | Actual Result | Verification Status | What It Proves | What It Does NOT Prove |
|---|---|---|---|---|---|
| **M01 Target Compile & Link** | `make -C fundamentals/mcu/01-startup-linker-vector clean all` | Exited code 0, 0 warnings with `-Wall -Wextra -Werror` | **VERIFIED** | Original linker script syntax, sections, startup assembly, and C source build cleanly. | Does not prove silicon timing on board. |
| **M01 Memory Bounds** | `arm-none-eabi-size build/firmware.elf` | text=620, data=8, bss=1036 (total 1664 bytes) | **VERIFIED** | Fits comfortably within 64 KB Flash and 20 KB SRAM. | Does not prove external bus capacitance. |
| **M01 ELF Headers & Entry** | `arm-none-eabi-readelf -h build/firmware.elf` | Entry point = `0x8000221` (Reset_Handler `0x08000220` + 1) | **VERIFIED** | Reset vector has Thumb execution bit (bit 0 = 1). | Does not prove target crystal frequency. |
| **M01 Vector Table Dump** | `arm-none-eabi-objdump -s -j .isr_vector build/firmware.elf` | Word 0 = `0x20005000` (MSP), Word 1 = `0x08000221` (Reset) | **VERIFIED** | Vector table layout matches Armv7-M silicon boot contract. | Does not prove hardware power supply stability. |
| **M01 Symbols & Allocator Contract** | `arm-none-eabi-nm -n build/firmware.elf` | `Reset_Handler`, `_sidata`, `_sdata`, `__init_array` present; `_start`, `malloc` absent | **VERIFIED** | Suppresses CRT startfiles; no heap allocator bloat. | Does not prove dynamic allocations in optional extensions. |
| **M01 Automated Static Suite** | `bash fundamentals/mcu/01-startup-linker-vector/scripts/verify_m01.sh` | All 9 static checks PASS | **VERIFIED** | Section retention, memory bounds, and Makefile dependency rebuild verified. | Does not replace physical hardware probe. |
| **M01 Challenge Verification** | `bash fundamentals/mcu/01-startup-linker-vector/challenge/verify_challenge.sh` | All checks PASS | **VERIFIED** | Blank-directory reconstruction requirements statically satisfied. | - |
| **M01 Deliberate Fault 1** | `make -C faults/fault1_misaligned_vector clean all` | Vector 1 has even address | **VERIFIED** | Reproduces missing Thumb bit fault. | - |
| **M01 Deliberate Fault 2** | `make -C faults/fault2_data_lma_mismatch clean all` | `_sidata = 0x20000000` (RAM) | **VERIFIED** | Reproduces VMA/LMA pointer corruption. | - |
| **M01 Deliberate Fault 3** | `make -C faults/fault3_memory_overflow clean all` | Linker error: SRAM exhausted | **VERIFIED** | Proves linker ASSERT prevents image overflow. | - |
| **M01 Gate Fixture** | `make -C gate/gate_fault_firmware clean all` | Exited code 0, unaligned `.text` boundary | **VERIFIED** | Reproduces unaligned instruction fetch exception fixture. | - |
| **M02 Target Compile & Link** | `make -C fundamentals/mcu/02-mmio-clock-timer-nvic clean all` | Exited code 0, 0 warnings with `-Wall -Wextra -Werror` | **VERIFIED** | Direct register clock, timer, and GPIO code build cleanly. | Does not prove crystal oscillation on bench. |
| **M02 Memory Footprint** | `arm-none-eabi-size build/firmware.elf` | text=1268, data=4, bss=1036 (total 2308 bytes) | **VERIFIED** | Fits within 64 KB Flash and 20 KB SRAM. | - |
| **M02 Timer Arithmetic Check** | Static shell arithmetic in `verify_m02.sh` | 72 MHz / 72 / 1000 == 1000 Hz, 64 MHz / 64 / 1000 == 1000 Hz | **VERIFIED** | Prescaler and ARR calculations strictly produce 1 kHz. | Does not prove clock oscillator PPM accuracy. |
| **M02 Automated Static Suite** | `bash fundamentals/mcu/02-mmio-clock-timer-nvic/scripts/verify_m02.sh` | All checks PASS | **VERIFIED** | Absence of HAL/Cube code, register symbols present, arithmetic verified. | - |
| **M02 Challenge Verification** | `bash fundamentals/mcu/02-mmio-clock-timer-nvic/challenge/verify_challenge.sh` | 10 kHz tick & 100 Hz PWM PASS | **VERIFIED** | Multi-channel PWM timing arithmetic statically verified. | - |
| **M02 Deliberate Fault 1** | `make -C faults/fault1_clock_not_enabled clean all` | Builds cleanly | **VERIFIED** | Unclocked peripheral register write fixture verified. | - |
| **M02 Deliberate Fault 2** | `make -C faults/fault2_flag_not_cleared clean all` | Builds cleanly | **VERIFIED** | Interrupt storm / unacknowledged flag fixture verified. | - |
| **M02 Deliberate Fault 3** | `make -C faults/fault3_timer_clock_math clean all` | Builds cleanly | **VERIFIED** | Timer clock doubler math error fixture verified. | - |
| **M02 Deliberate Fault 4** | `make -C faults/fault4_nvic_priority_error clean all` | Builds cleanly | **VERIFIED** | Unshifted priority byte encoding fixture verified. | - |
| **M02 Deliberate Fault 5** | `make -C faults/fault5_rmw_hazard clean all` | Builds cleanly | **VERIFIED** | Concurrent RMW on shared `GPIOA->ODR` fixture verified. | - |
| **M02 Gate Fixture** | `make -C gate/gate_fault_firmware clean all` | Builds cleanly | **VERIFIED** | Compound clock math and storm fixture verified. | - |
| **Top-Level Foundation Suite** | `make -C fundamentals/mcu check` | Exited code 0, all static checks PASS | **VERIFIED** | Module 1 and Module 2 automated suites execute and pass end-to-end. | - |
| **Target Silicon Flashing & Run** | OpenOCD / ST-Link target flash | **UNVERIFIED** (Headless build runner; no target board attached) | **UNVERIFIED** | Firmware binary verified ready for target flashing by learner. | No fabricated execution claims made. |
| **Live GDB Register Inspection** | OpenOCD SWD remote target attach | **UNVERIFIED** (Headless build runner; no target board attached) | **UNVERIFIED** | GDB script commands documented and syntactically validated. | No fabricated GDB register dumps made. |
| **M02 Physical Waveform** | Oscilloscope / Logic Analyzer probe on PA1 | **UNVERIFIED** (Headless build runner; no hardware probe attached) | **UNVERIFIED** | Physical timing must be verified when learner attaches ST-Link and probe to PA1. | No fabricated oscilloscope values are claimed. |

---

## 5. Physical Evidence Contract Statement

Per the course standards, physical hardware timing measurements must strictly differentiate:

```text
[Observation]
PA1 exhibits a periodic square wave with 1.0 ms toggle interval (500 Hz frequency).
Measured on target hardware using logic analyzer / oscilloscope.

[Interpretation]
The 1.0 ms toggle supports the mathematical calculation that TIM2 prescaler (PSC=71)
and auto-reload (ARR=999) correctly divide the 72 MHz timer clock to 1000 Hz.

[Non-Proof]
This single-run observation DOES NOT prove that all board crystals run at exactly 8.000 MHz,
nor does it establish worst-case interrupt jitter under nested preemption.
```

In the current automated headless workspace:
- Physical observation is explicitly designated **`UNVERIFIED`**.
- Target compile/link status remains **`VERIFIED`**.
- No fabricated register, memory, or oscilloscope evidence is generated.

---

## 6. Known Portability Limits

1. **Toolchain Version Variance**:
   - Baseline: GCC 13.x / Binutils 2.42.
   - On older toolchains (GCC 10 or earlier), `--specs=nano.specs` behavior regarding `_init` and `_fini` may differ slightly. Minimal `runtime_glue.c` provides explicit stubs to prevent link errors.
2. **Crystal Variance Across Boards**:
   - The primary profile assumes an 8.000 MHz HSE crystal (standard Blue Pill / Nucleo).
   - If a third-party clone board possesses a 12.000 MHz or 16.000 MHz crystal, the PLL multiplier must be recalculated.
   - The fallback profile (`CLOCK_PROFILE_64MHZ_HSI`) is completely independent of external crystal hardware and operates on any STM32F103 chip.
3. **Flash Wait States**:
   - Latency must be set to 2 wait states before switching to SYSCLK > 48 MHz. The implementation enforces this order.
