# Lab 02: Dynamic Core Clock Coherence and SysTick Timer Reload Calculation

## Objective
Analyze the mathematical contract between the STM32F103 clock tree, the Cortex-M SysTick peripheral, and FreeRTOS timebase tracking, demonstrating why dynamic clock coherence (`SystemCoreClock`) prevents timing drift under oscillator fallback conditions.

## Prerequisites
- P2-M02: STM32F103 Clock tree architecture (HSE 72 MHz primary vs HSI 64 MHz fallback).
- Lab 01: FreeRTOS kernel integration and `FreeRTOSConfig.h`.

## Environment
- Target: STM32F103C8T6 (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM).
- Toolchain: Arm GNU Toolchain 13.3.rel1 / Ubuntu GCC 13.2.1 cross-compiler.

## Estimated Time
- 60 minutes (MUST load).

## AI Mode
- **AI-Hint**: Socratic guidance permitted on timer reload derivation, downcounter operation, and clock failover impact. Direct code generation prohibited.

## Architectural Principles

### 1. The SysTick 24-Bit Downcounter
The Cortex-M3 SysTick peripheral contains three core registers:
- `SysTick->LOAD` (Reload value, 24 bits: `0x000000` to `0xFFFFFF`, maximum $16,777,215$).
- `SysTick->VAL` (Current counter value, 24 bits downcounter).
- `SysTick->CTRL` (Control and status: `ENABLE`, `TICKINT`, `CLKSOURCE`).

When enabled with processor clock (`CLKSOURCE = 1`), the counter decrements by 1 every CPU clock cycle. When `VAL` transitions from 1 to 0:
1. The counter reloads `SysTick->LOAD` on the next clock cycle.
2. The `COUNTFLAG` bit in `SysTick->CTRL` is set to 1.
3. If `TICKINT == 1`, a SysTick exception request (Vector 15) is asserted to the NVIC.

### 2. SysTick Reload Mathematical Contract
To generate a periodic tick frequency $f_{\text{tick}} = \text{configTICK\_RATE\_HZ} = 1000\text{ Hz}$ ($1\text{ ms}$ period) from CPU clock $f_{\text{cpu}}$:
$$\text{Period in cycles} = \frac{f_{\text{cpu}}}{f_{\text{tick}}}$$
Because the downcounter counts down to 0 and reloads on the subsequent cycle, the reload value programmed into `SysTick->LOAD` must be:
$$\text{LOAD} = \left( \frac{\text{configCPU\_CLOCK\_HZ}}{\text{configTICK\_RATE\_HZ}} \right) - 1$$

#### Canonical 72 MHz HSE Primary Profile:
$$\text{LOAD}_{72} = \left( \frac{72,000,000}{1000} \right) - 1 = 72,000 - 1 = 71,999 \quad (\texttt{0x1193F})$$
Since $71,999 \le 16,777,215$, this fits comfortably within the 24-bit reload register.

#### 64 MHz HSI Fallback Profile:
$$\text{LOAD}_{64} = \left( \frac{64,000,000}{1000} \right) - 1 = 64,000 - 1 = 63,999 \quad (\texttt{0xF9FF})$$
$63,999 \le 16,777,215$, fully compliant with 24-bit limits.

### 3. Clock Fallback Drift Analysis
In production systems, if an external crystal (HSE) fails or is omitted, firmware falls back to the internal 8 MHz RC oscillator with PLL ($64\text{ MHz}$).

If `configCPU_CLOCK_HZ` were statically hardcoded as `72000000UL`:
1. `port.c` programs `SysTick->LOAD = 71,999`.
2. The CPU is actually running at $64\text{ MHz}$.
3. The true interrupt rate becomes:
   $$f_{\text{actual}} = \frac{64,000,000\text{ Hz}}{72,000\text{ cycles}} \approx 888.89\text{ Hz}$$
4. Real-world tick interval:
   $$T_{\text{actual}} = \frac{72,000}{64,000,000} = 1.125\text{ ms} \quad (\text{12.5\% timing dilation})$$
Any task calling `vTaskDelay(pdMS_TO_TICKS(1000))` would sleep for $1.125\text{ s}$ instead of $1.000\text{ s}$, corrupting communications timeouts, motor commutation, and sensor sampling rates.

### 4. Dynamic Coherence Implementation
To ensure absolute coherence across clock profiles:
1. `FreeRTOSConfig.h` declares:
   ```c
   extern uint32_t SystemCoreClock;
   #define configCPU_CLOCK_HZ (SystemCoreClock)
   ```
2. `clock_init()` determines whether HSE locked or HSI fallback engaged, computes the resulting core clock, and updates `SystemCoreClock`:
   ```c
   if (hse_ready) {
       SystemCoreClock = 72000000UL;
   } else {
       SystemCoreClock = 64000000UL;
   }
   ```
3. When `vTaskStartScheduler()` calls `vPortSetupTimerInterrupt()`, it dynamically computes:
   `portNVIC_SYSTICK_LOAD_REG = (configCPU_CLOCK_HZ / configTICK_RATE_HZ) - 1UL;`
   guaranteeing an exact 1000 Hz tick regardless of the active clock source.

## Step-by-Step Procedure

1. **Verify Static Calculation**:
   Inspect `port.c` line in `vPortSetupTimerInterrupt`:
   ```c
   portNVIC_SYSTICK_LOAD_REG = ( configCPU_CLOCK_HZ / configTICK_RATE_HZ ) - 1UL;
   ```
2. **Examine Clock Init Contract**:
   Inspect `src/clock.c`:
   Confirm that `SystemCoreClock` is updated upon configuring PLL and flash latency.
3. **Inspect Disassembly**:
   Disassemble `vPortSetupTimerInterrupt`:
   ```bash
   arm-none-eabi-objdump -d build/firmware.elf | grep -A 20 "<vPortSetupTimerInterrupt>:"
   ```
   Notice that the loader reads the value stored in the `SystemCoreClock` RAM/literal pointer and divides by 1000.
4. **Compile and Run Verification**:
   ```bash
   bash scripts/verify_m04.sh
   ```

## Expected Observations & Verification
- `SystemCoreClock` symbol is present in `.data` / `.bss`.
- `LOAD` register value dynamically evaluates to `71,999` (`0x1193F`) under 72 MHz HSE or `63,999` (`0xF9FF`) under 64 MHz HSI.
- Zero drift between physical time and `xTickCount` increments.

## Actual Verification Status
- **Static Math & Disassembly Analysis**: **VERIFIED** on host cross-compiler.
- **Oscilloscope SysTick Pin Toggle**: **UNVERIFIED** (Headless build environment; no physical probe attached).
