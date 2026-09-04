# Phase 2 M01 and M02 Implementation & Verification Notes

> Status: **Author Implementation Complete — Leader Review Required**  
> Author: Antigravity Automated Bare-Metal Subsystem Engineer  
> Date: **2026-09-04**  
> Baseline Reference: Issue #16, `roadmap/phase-2-stm32-freertos.md`, `research/phase-2/2026-09-03-stm32-freertos-curriculum-design.md`, Leader Rework #1 (Issue #16 comment `5540619118`), Leader Rework #2 (Issue #16 comment `5541016423`)  
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
- [x] Challenge reference isolation: references moved to `reviewer/challenge-reference/`, learner READMEs clean.
- [x] Assessment validity: disassembly & relocation inspection, dynamic mutation suites, novel OPM Gate fault.

---

## 2. Execution Environment & Toolchain Identity

Per Leader Rework #1, the canonical baseline and the actual execution environment are separated and recorded with strict version fidelity:

### Canonical Target Toolchain Baseline
- **Specification**: Arm GNU Toolchain 13.3.rel1
- **Expected Components**: GCC 13.3.1, GNU Binutils 2.42, GDB 14.2, Newlib 4.4.0
- **Status**: **PARTIALLY VERIFIED** (Target architecture contracts, compiler flags `-mcpu=cortex-m3 -mthumb`, and Binutils 2.42 linker scripts are verified; however, local compilation was executed using the Ubuntu package cross-compiler on the test host).

### Actual Test Host Execution Environment
- **Host System**: Linux 6.6 / Ubuntu 24.04.1 LTS on WSL2 (Windows 11)
- **C Cross-Compiler**: `arm-none-eabi-gcc (Ubuntu 15:13.2.rel1-2) 13.2.1 20231009`
- **Linker / Binary Utilities**: `GNU ld (2.42-1ubuntu1+23) 2.42`, `arm-none-eabi-readelf`, `arm-none-eabi-objdump`, `arm-none-eabi-nm`, `arm-none-eabi-size`
- **C Library**: `Newlib 4.4.0 (libnewlib-arm-none-eabi 4.4.0.20231231-2)`
- **Debugger**: `GNU GDB (Ubuntu 15.1-1ubuntu1~24.04.1) 15.1`
- **Build System**: GNU Make 4.3 (WSL2)
- **Status**: **VERIFIED** on host for all compile, link, and static binary verification checks.

---

## 3. Authoritative Upstream Sources & Source Ledger

Repository canonical tier classification:
- **T0**: Specifications, datasheets, architecture references, and standards.
- **T1**: Upstream source code and pinned headers.
- **T2**: Official toolchain documentation and manuals.

1. **ST Reference Manual RM0008**: Rev 21 (Feb 2021) — **T0**
2. **ST Programming Manual PM0056**: Rev 7 (Dec 2024) — **T0**
3. **ST Datasheet DS5319**: Rev 20 (Jul 2025) — **T0**
4. **Armv7-M Architecture Reference Manual**: ARM DDI 0403E.e — **T0**
5. **Arm CMSIS_5**: Tag `5.9.0` (commit `2b7495b8535bdcb306dac29b9ded4cfb679d7e5c`) — **T1**
6. **ST cmsis-device-f1**: Tag `v4.3.5` (commit `8a76309ed1250d817e9c888c4417171d2ba3ba63`) — **T1**
7. **GNU LD Manual**: Binutils 2.42 — **T2**
8. **Arm GNU Toolchain Documentation**: 13.3.rel1 / GCC 13 manual — **T2**

---

## 4. Verification Evidence Matrix

All verification claims are audited against actual execution:
- **VERIFIED**: Static, binary, or build execution performed directly on host with concrete output matching expectations.
- **PARTIALLY VERIFIED**: Binary or static evidence confirms the seeded property, but dynamic target symptom is not physically executed on silicon.
- **UNVERIFIED**: Physical hardware runs, oscilloscope waveforms, and live GDB sessions (no board attached to headless host).

| Check / Domain | Command / Procedure | Actual Result | Verification Status | What It Proves | What It Does NOT Prove |
|---|---|---|---|---|---|
| **M01 Target Compile & Link** | `make -C fundamentals/mcu/01-startup-linker-vector clean all` | Exited code 0, 0 warnings with `-Wall -Wextra -Werror` | **VERIFIED** | Original linker script syntax, sections, startup assembly, and C source build cleanly on host. | Does not prove silicon execution timing on board. |
| **M01 Memory Bounds** | `arm-none-eabi-size build/firmware.elf` | text=620, data=8, bss=1036 (total 1664 bytes) | **VERIFIED** | Firmware fits within 64 KB Flash and 20 KB SRAM. | Does not prove external bus capacitance or supply voltage margins. |
| **M01 ELF Headers & Entry** | `arm-none-eabi-readelf -h build/firmware.elf` | Entry point = `0x8000221` (Reset_Handler `0x08000220` + 1) | **VERIFIED** | ELF header entry point has Thumb execution bit (bit 0 = 1). | Does not prove vector table itself without decoding vector memory. |
| **M01 Vector Entry 0 & 1** | Decoded `.isr_vector` in `verify_m01.sh` | Word 0 = `0x20005000` (MSP), Word 1 = `0x08000221` (Thumb Reset) | **VERIFIED** | Vector table words 0 and 1 strictly match silicon reset boot contract. | Does not prove power-on reset rise time. |
| **M01 Symbols & Allocator Contract** | `arm-none-eabi-nm -n build/firmware.elf` | `Reset_Handler`, `_sidata`, `_sdata`, `__init_array` present; `_start`, `malloc` absent | **VERIFIED** | Suppresses CRT startfiles; no heap allocator bloat. | Does not prove dynamic allocations in optional extensions. |
| **M01 Automated Static Suite** | `bash fundamentals/mcu/01-startup-linker-vector/scripts/verify_m01.sh` | All 9 static checks PASS | **VERIFIED** | Memory bounds, ELF entry, vector 0/1, sections, and Makefile dependency tracking verified. | Does not replace physical hardware probe. |
| **M01 Challenge Validator & Mutations** | `bash fundamentals/mcu/01-startup-linker-vector/challenge/verify_challenge.sh` | Reference PASSES; all 6 negative mutations rejected | **VERIFIED** | Validator inspects linked binary and disassembly (SystemInit, copy/zero loops, init_array, main transfer) and catches all mutations. | Does not evaluate coding style or manual documentation quality. |
| **M01 Fault F1 (Missing Thumb bit)** | `make -C faults/f1 clean all` && `arm-none-eabi-readelf -x .isr_vector` | Vector 1 has even address `0x08000090` | **PARTIALLY VERIFIED** | Binary has even address in vector 1. | Target `UsageFault (INVSTATE)` remains UNVERIFIED without hardware. |
| **M01 Fault F2 (LMA/VMA Mismatch)** | `make -C faults/f2 clean all` && `arm-none-eabi-readelf -s` | `_sidata = 0x20000000` (RAM instead of Flash) | **PARTIALLY VERIFIED** | Linker symbol `_sidata` incorrectly points to RAM VMA. | Target memory corruption remains UNVERIFIED without hardware. |
| **M01 Fault F3 (Memory Overflow)** | `make -C faults/f3 clean all` | Linker error: SRAM exhausted (ASSERT triggered) | **VERIFIED** | Linker assertion statically halts build on overflow. | Does not prove dynamic stack collision during runtime. |
| **M01 Gate Fixture** | `bash fundamentals/mcu/01-startup-linker-vector/reviewer/verify_gate_regression.sh` | `.boot_meta` at `0x08000000`, `.isr_vector` displaced to `0x08000020` | **PARTIALLY VERIFIED** | Binary section headers and memory dump prove vector displacement. | Target reset crash / HardFault remains UNVERIFIED without hardware. |
| **M02 Target Compile & Link** | `make -C fundamentals/mcu/02-mmio-clock-timer-nvic clean all` | Exited code 0, 0 warnings with `-Wall -Wextra -Werror` | **VERIFIED** | Direct register clock (with bounded timeouts), timer, and GPIO code build cleanly. | Does not prove crystal oscillation on bench. |
| **M02 Memory Footprint** | `arm-none-eabi-size build/firmware.elf` | text=1460, data=4, bss=1036 (total 2500 bytes) | **VERIFIED** | Fits within 64 KB Flash and 20 KB SRAM. | - |
| **M02 Timer Arithmetic Check** | Static shell arithmetic in `verify_m02.sh` | 72 MHz / 72 / 1000 == 1000 Hz update event rate | **VERIFIED** | Prescaler and ARR calculations strictly produce 1 kHz event rate (500 Hz toggle square wave). | Does not prove crystal PPM tolerance. |
| **M02 Bounded Clock Initialization** | Code inspection & compile of `clock.c` | Bounded loops with explicit retry counters for HSE/HSI, PLL lock, and SWS switch | **VERIFIED** | Prevents infinite loop hang on oscillator/PLL failure; caller receives explicit success/fail status. | Hardware fallback transition remains UNVERIFIED without physical clock glitching. |
| **M02 Automated Static Suite** | `bash fundamentals/mcu/02-mmio-clock-timer-nvic/scripts/verify_m02.sh` | All checks PASS | **VERIFIED** | Absence of HAL/Cube code, register symbols present, arithmetic verified. | Does not prove physical square wave. |
| **M02 Challenge Validator & Mutations** | `bash fundamentals/mcu/02-mmio-clock-timer-nvic/challenge/verify_challenge.sh` | Reference PASSES; all 6 negative mutations rejected | **VERIFIED** | Host unit harness tests bounds/wrap/ODR; cross-compilation disassembly verifies ARR=99, DIER, UIF clear, BSRR/BRR, 0 ODR, 4 channels, wrap. | Physical PWM duty cycle accuracy on pins remains UNVERIFIED without oscilloscope. |
| **M02 Fault F1 (Unclocked Peripheral)** | `make -C faults/f1 clean all` | Builds without APB1 timer clock enable | **PARTIALLY VERIFIED** | Source code confirms RCC APB1ENR clock gate omitted. | Silent register write ignore on peripheral bus remains UNVERIFIED without hardware. |
| **M02 Fault F2 (Uncleared UIF Flag)** | `make -C faults/f2 clean all` && `arm-none-eabi-objdump -d` | Disassembly confirms no store to `TIM2->SR` | **PARTIALLY VERIFIED** | Disassembly proves interrupt flag is never cleared. | Target interrupt storm and core starvation remain UNVERIFIED without hardware. |
| **M02 Fault F3 (Timer Doubler Math)** | `make -C faults/f3 clean all` && Disassembly | Prescaler set to 35 (2000 events/s) | **PARTIALLY VERIFIED** | Disassembly confirms PSC=35 derived from halved clock assumption. | 1 kHz output square wave remains UNVERIFIED without oscilloscope. |
| **M02 Fault F4 (NVIC Priority Encoding)** | `make -C faults/f4 clean all` | Raw logical 6 written to unshifted `NVIC->IP` | **PARTIALLY VERIFIED** | Source confirms raw integer write without `<< 4` shift. | Hardware reading back 0x00 from unimplemented bits [3:0] remains UNVERIFIED without hardware. |
| **M02 Fault F5 (RMW Concurrency Hazard)** | `make -C faults/f5 clean all` && Disassembly | Disassembly confirms non-atomic `LDR-EOR-STR` sequence on `GPIOA->ODR` | **PARTIALLY VERIFIED** | Non-atomic instruction sequence proven in ELF disassembly. | Intermittent pulse loss remains UNVERIFIED without logic analyzer under interrupt load. |
| **M02 Gate Fixture (One-Pulse Mode)** | `bash fundamentals/mcu/02-mmio-clock-timer-nvic/reviewer/verify_gate_regression.sh` | Disassembly proves CR1 configured with OPM and ISR clears SR | **PARTIALLY VERIFIED** | Disassembly confirms presence of seeded OPM fault and clean ISR flag clearance. | Target execution single-pulse halt remains UNVERIFIED without hardware. |
| **Top-Level Foundation Suite** | `make -C fundamentals/mcu check` | Exited code 0, all static checks PASS | **VERIFIED** | Module 1 and Module 2 automated suites execute and pass end-to-end. | - |
| **Target Silicon Flashing & Run** | OpenOCD / ST-Link target flash | None (Headless runner; no hardware attached) | **UNVERIFIED** | - | Physical flashing, run-mode entry, and reset behavior. |
| **Live GDB Register Inspection** | OpenOCD SWD remote target attach | None (Headless runner; no hardware attached) | **UNVERIFIED** | - | Live target register reads (`TIM2->SR`, `NVIC->IP`). GDB commands are illustrative. |
| **Physical Waveform Measurement** | Oscilloscope / Logic Analyzer probe on PA0..PA3, PC13 | None (Headless runner; no hardware probe attached) | **UNVERIFIED** | - | Physical pulse widths, toggle frequencies, and rise/fall times. All values are expected calculations. |

---

## 5. Physical Evidence Contract Statement

Per the course standards, physical hardware timing measurements must strictly differentiate:

```text
[EXPECTED / TO RECORD ON TARGET]
PA1 exhibits a periodic square wave with 1.0 ms toggle interval (500 Hz frequency, 2.0 ms full period).
To be measured on target hardware using logic analyzer / oscilloscope.

[Interpretation]
The 1.0 ms toggle supports the mathematical calculation that TIM2 prescaler (PSC=71)
and auto-reload (ARR=999) correctly divide the 72 MHz timer clock to 1000 Hz update events.

[Non-Proof]
This single-run observation DOES NOT prove that all board crystals run at exactly 8.000 MHz,
nor does it establish worst-case interrupt jitter under nested preemption.
```

If no physical oscilloscope is connected during build:
- Physical observation is marked **`UNVERIFIED`**.
- Target compile/link status remains **`VERIFIED`**.
- No fabricated waveform outputs are presented.
