# Lab 04: DMA1 Channel 1 Circular Acquisition and Buffer Memory Lifecycle

## Objective
Configure DMA1 Channel 1 for continuous, circular peripheral-to-memory transfers from `ADC1->DR` into a 128-sample static SRAM buffer (`g_adc_buffer`), configure transfer data widths, and reason about DMA buffer lifetime.

## Prerequisites
- Lab 01, Lab 02, Lab 03.
- Phase 1 storage duration and memory lifetime models (static vs automatic duration).

## Environment
- Target: STM32F103C8T6.
- Toolchain: Arm GNU Toolchain 13.3.rel1 / Ubuntu GCC 13.2.1.

## Estimated Time
- 45 minutes (MUST load).

## AI Mode
- **AI-Hint**: Conceptual help on DMA address registers and bus matrix allowed.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition clean all
```

## Procedure
1. Fixed DMA Request Mapping on STM32F103:
   - According to RM0008 Section 13.3.7 Table 78, DMA1 Channel 1 is dedicated to ADC1.
   - (Unlike STM32F4/G4/H7, STM32F103 has no DMAMUX; channels have hardwired peripheral request lines).
2. Enable DMA1 clock in `RCC->AHBENR[DMA1EN]`.
3. Disable channel before configuration: `DMA1_Channel1->CCR &= ~DMA_CCR_EN`.
4. Configure Peripheral & Memory Addresses:
   - `DMA1_Channel1->CPAR = (uint32_t)&(ADC1->DR);`
   - `DMA1_Channel1->CMAR = (uint32_t)g_adc_buffer;`
5. Configure Counter (`CNDTR`):
   - `DMA1_Channel1->CNDTR = 128;` (Total 128 half-words = 256 bytes).
6. Configure Channel Control Register (`CCR`):
   - `DIR = 0` (Peripheral-to-Memory).
   - `CIRC = 1` (Circular mode: automatically reload `CNDTR` to 128 upon reaching 0).
   - `PINC = 0` (Peripheral increment disabled: always read from `ADC1->DR`).
   - `MINC = 1` (Memory increment enabled: step through SRAM array).
   - `PSIZE = 01` (16-bit peripheral data size matching ADC 12-bit right-aligned data).
   - `MSIZE = 01` (16-bit memory data size matching `uint16_t` array).
7. Enable ADC DMA request generation: `ADC1->CR2 |= ADC_CR2_DMA;`.
8. Enable DMA1 Channel 1: `DMA1_Channel1->CCR |= DMA_CCR_EN;`.

## Buffer Lifetime & Ownership Rules
- **CRITICAL**: The DMA destination buffer `g_adc_buffer` **must have static storage duration** (global or file-scope static).
- If software allocates the buffer as a local variable on the stack inside an initialization function, the stack frame is reclaimed when the function returns. As the stack pointer moves and other functions execute, the active DMA controller silently writes incoming ADC data into the active stack of unrelated functions, corrupting local variables and return addresses!

## Expected Observation
- Once DMA is enabled and TIM3 triggers fire, reading `DMA1_Channel1->CNDTR` shows a continuously decrementing value cycling from 128 down to 1 and wrapping back to 128.
- GDB memory inspection:
  ```gdb
  p/x DMA1_Channel1->CNDTR
  # Returns a value between 1 and 128, changing on successive reads
  x/16hx g_adc_buffer[0]
  # Shows 12-bit ADC conversion readings (values between 0x000 and 0xFFF)
  ```

## Actual Verification Status
- **Static & Disassembly Verification**: **VERIFIED** on host cross-compiler.
- **Live Memory Inspection**: **UNVERIFIED** (No hardware probe attached).

## Questions
1. What happens if `MSIZE` is configured as 8-bit (00) while `PSIZE` is 16-bit (01)? How does the DMA controller truncate or pack the data?
2. Why is circular mode (`CIRC=1`) preferred over normal mode for continuous audio or telemetry streaming?

## Failure Modes
- Forgetting to set `ADC_CR2_DMA`, resulting in `CNDTR` remaining permanently frozen at 128.
- Configuring `CPAR` with `&ADC1` instead of `&ADC1->DR`.

## Debug Strategy
- Check `DMA1_Channel1->CNDTR`:
  - If frozen at initial value: verify TIM3 TRGO, ADC external trigger, and `ADC_CR2_DMA` bit.
  - If decrementing: DMA is actively streaming across the AHB bus.

## Challenge
Calculate the total AHB bus bandwidth consumed by this 10 ksample/s 16-bit acquisition stream. What percentage of the 72 MHz AHB bus capacity does it represent?

## Cleanup
DMA channel remains enabled for interrupt milestone handling in Lab 05.

## Sources
- ST RM0008 Rev 21, Section 13 (DMA controller: Channel 1 mapping, registers, and circular mode).
