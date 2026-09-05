# Lab 02: ADC Power-Up, Hardware Calibration Sequence, and Regular Sequence Configuration

## Objective
Implement the hardware calibration sequence specified in ST RM0008 Section 11.4 with bounded timeouts, configure PA0 as analog input, and set up a single-conversion regular channel sequence.

## Prerequisites
- Lab 01 (ADC clock tree and prescaler configuration).

## Environment
- Target: STM32F103C8T6.
- Toolchain: Arm GNU Toolchain 13.3.rel1 / Ubuntu GCC 13.2.1 cross-compiler.

## Estimated Time
- 40 minutes (MUST load).

## AI Mode
- **AI-Hint**: Conceptual questions on calibration hardware registers allowed. No copying vendor HAL calibration macros.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition clean all
```

## Procedure
1. Enable `RCC->APB2ENR` bits for `ADC1EN` and `IOPAEN`.
2. Configure PA0 (`CRL` bits [3:0]): `MODE0 = 00` (Input), `CNF0 = 00` (Analog).
3. Execute the mandatory RM0008 Section 11.4 calibration sequence:
   ```text
   Step 1: ADC1->CR2 |= ADC_CR2_ADON; (Wake ADC from power-down)
   Step 2: Wait stabilization delay t_STAB (~1 us)
   Step 3: ADC1->CR2 |= ADC_CR2_RSTCAL; (Reset calibration registers)
   Step 4: Poll (ADC1->CR2 & ADC_CR2_RSTCAL) until 0 with bounded loop counter
   Step 5: ADC1->CR2 |= ADC_CR2_CAL; (Launch calibration)
   Step 6: Poll (ADC1->CR2 & ADC_CR2_CAL) until 0 with bounded loop counter
   ```
4. Handle timeout failures explicitly:
   - If `RSTCAL` or `CAL` does not clear before timeout, abort initialization and return diagnosable error codes (`ADC_INIT_ERR_RSTCAL_TIMEOUT` / `ADC_INIT_ERR_CAL_TIMEOUT`).
   - Do **NOT** use unconstrained `while(ADC1->CR2 & ADC_CR2_CAL);` which hangs the microcontroller on broken silicon or unclocked peripheral state.
5. Configure Regular Sequence Registers:
   - Set total number of regular conversions in sequence: `ADC1->SQR1[L[3:0]] = 0000` (1 conversion).
   - Set first regular conversion channel: `ADC1->SQR3[SQ1[4:0]] = 00000` (Channel 0 / PA0).

## Expected Observation
- At power-up, `RSTCAL` sets and quickly clears as calibration registers are reset.
- `CAL` sets and clears after internal offset calibration completes (~several hundred ADCCLK cycles).
- Return value of `adc_init()` is `ADC_INIT_OK` (0).
- GDB register inspection:
  ```gdb
  p/x ADC1->CR2
  # Expected: ADON set (bit 0), RSTCAL cleared (bit 3 == 0), CAL cleared (bit 2 == 0)
  p/x ADC1->SQR1 & 0x00F00000
  # Expected: 0x0 (L = 0 -> 1 conversion)
  p/x ADC1->SQR3 & 0x1F
  # Expected: 0x0 (SQ1 = 0 -> Channel 0)
  ```

## Actual Verification Status
- **Static & Disassembly Verification**: **VERIFIED** on host cross-compiler.
- **Live Silicon Execution**: **UNVERIFIED** (No hardware probe attached).

## Questions
1. Why does the STM32F103 require setting `ADON` twice if starting conversions in software mode?
2. What happens to ADC conversion accuracy if software omits the calibration sequence after power-up?

## Failure Modes
- Setting `CAL` without first clearing/resetting via `RSTCAL`.
- Missing bounded polling loop, causing an unrecoverable CPU lockup if the ADC clock gate is disabled.

## Debug Strategy
- Check `RCC->APB2ENR` to ensure `ADC1EN` is set before touching any `ADC1` register.
- Check return value of `adc_init()` in caller; do not proceed with acquisition if calibration fails.

## Challenge
Measure the cycle duration of `CAL` using the DWT cycle counter (`DWT->CYCCNT`) and convert it to microseconds at 72 MHz.

## Cleanup
Ensure regular sequence is clean before configuring hardware triggers in Lab 03.

## Sources
- ST RM0008 Rev 21, Section 11.4 (Calibration sequence) & Section 11.12 (ADC register descriptions).
