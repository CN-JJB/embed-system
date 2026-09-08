# Phase 2 Final Gate: Target Hardware & Toolchain Environment

## 1. MCU Silicon Contract

All Phase 2 Final Gate firmware images and memory maps target the following exact silicon specification:

* **MCU:** STMicroelectronics STM32F103C8T6
* **Core:** Arm Cortex-M3 (Armv7-M architecture, Rev r1p1 / r2p0)
* **Flash Memory:** 64 KB physical Flash (`0x08000000` to `0x0800FFFF`)
* **SRAM Memory:** 20 KB physical SRAM (`0x20000000` to `0x20004FFF`)
* **Peripherals Utilized:**
  - RCC (Reset and Clock Control: HSE, PLL, APB1, APB2, ADCPRE)
  - NVIC (4 bits preemption priority, 16 priority levels)
  - TIM3 (General-purpose 16-bit timer with TRGO update generation)
  - ADC1 (12-bit SAR ADC, PA0 regular external trigger)
  - DMA1 (7-channel DMA controller, Channel 1 for ADC1 circular transfer)
  - USART1 (Asynchronous serial communication, PA9 TX / PA10 RX)
  - IWDG (Independent Watchdog with dedicated LSI 40 kHz clock)
  - DWT (Data Watchpoint and Trace unit, CYCCNT cycle counter)
  - CoreDebug (DEMCR TRCENA)

---

## 2. Supported Board Profiles

The assessment supports multiple board form-factors. Learners must record their actual target board in `SUBMISSION_TEMPLATE.md`:

### Profile 1: Minimal STM32F103C8 Development Board ("Blue Pill" / Core Board)
* 8 MHz HSE crystal oscillator present and verified.
* SYSCLK = 72 MHz via PLL ($\times 9$).
* User LED on PC13 (active LOW).
* SWD 4-pin header: GND, SWCLK, SWDIO, 3.3V.
* Test Pins: PA0 (ADC in), PA1–PA4 (GPIO timing observation markers).

### Profile 2: Minimal Development Board with HSI Fallback
* HSE crystal absent or non-functional.
* SYSCLK = 64 MHz via HSI/2 ($\times 16$).
* Learner must document clock prescaler adjustments for TIM3, USART1, and ADCPRE.

### Profile 3: STMicroelectronics NUCLEO-F103RB
* STM32F103RBT6 (128 KB Flash, 20 KB SRAM).
* Linker script must enforce the 64 KB Flash ceiling (`LENGTH = 64K`) to maintain assessment equivalence.
* Clock source: 8 MHz MCO from ST-Link or internal HSI.
* User LED on PA5.

> [!CAUTION]
> Do not silently assume all learners have identical Blue Pill hardware. Verify crystal frequency and pinout before applying power or flashing.

---

## 3. Required Test Equipment for Physical Evidence

To capture full live physical evidence and achieve an unconditioned PASS, the learner environment must include:

1. **Hardware Debug Probe:** ST-Link V2, CMSIS-DAP (DAPLink), or SEGGER J-Link connected via 4-wire SWD.
2. **Signal Measurement:** 2-channel digital storage oscilloscope or 8-channel logic analyzer (minimum 24 MHz sample rate) for GPIO timing markers.
3. **Analog Signal Source:** 10 kΩ potentiometer or DC power supply providing 0.0 V to 3.3 V to pin PA0.
4. **Serial Telemetry Adapter:** USB-to-UART bridge (FTDI, CP2102, CH340) attached to PA9 (USART1 TX) at 115200 baud, 8N1.

### Equipment Unavailability & Headless Rehearsal
If physical hardware or probe equipment is unavailable, learners may perform static, ELF, map, and disassembly analysis as a rehearsal. However:
* All hardware-dependent rubric items must be documented honestly as `UNVERIFIED`.
* **A final real-world Gate PASS cannot be awarded without verified target execution and live evidence.**

---

## 4. Toolchain Environment Comparison

```
+====================================================================================================+
|                                    TOOLCHAIN BASELINE COMPARISON                                   |
+=====================+======================================+=======================================+
| Component           | Canonical Project Baseline           | Actual Host Toolchain (Recorded)      |
+=====================+======================================+=======================================+
| Host OS             | Ubuntu Linux 22.04 / 24.04 LTS       | Ubuntu 24.04 LTS on WSL2 (Win 11)     |
| Cross Compiler      | Arm GNU Toolchain 13.3.rel1          | arm-none-eabi-gcc 13.2.1 20231009     |
|                     | (GCC 13.3.1 20240614)                | (15:13.2.rel1-2 Ubuntu package)       |
| Binutils            | GNU Binutils 2.42                    | GNU Binutils 2.42                     |
| GDB                 | GNU GDB 14.2                         | GNU GDB 15.1                          |
| C Runtime Library   | Newlib-nano 4.4.0                    | Newlib-nano 4.4.0                     |
| Build System        | GNU Make 4.4+                        | GNU Make 4.3                          |
| Debug Server        | OpenOCD 0.12.0                       | OpenOCD 0.12.0                        |
+=====================+======================================+=======================================+
```
