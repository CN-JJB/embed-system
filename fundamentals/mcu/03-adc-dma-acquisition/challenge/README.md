# P2-M03 Challenge: Autonomous Hardware Acquisition Pipeline

## Challenge Mission
Construct an autonomous analog data acquisition subsystem on STM32F103 using direct CMSIS register access:

```text
TIM3 Update @ 10 kHz
  ──► TIM3 TRGO (MMS = 010)
  ──► ADC1 Regular External Trigger (EXTSEL = 100, EXTTRIG = 1)
  ──► ADC1 Conversion (PA0, SMP0 = 55.5 cycles, ADCPRE = /6)
  ──► ADC1 DMA Request
  ──► DMA1 Channel 1 (CPAR = &ADC1->DR, CMAR = g_acq_buffer, CNDTR = 128)
  ──► Circular SRAM Buffer (2x64 16-bit samples)
  ──► Half-Transfer (HT) ISR -> pulse PA3
  ──► Transfer-Complete (TC) ISR -> pulse PA4
```

## Architectural Invariants
1. **Clock Safety**: $f_{\text{ADCCLK}} \le 14\text{ MHz}$ under all conditions. Software must configure `ADCPRE = /6` in `RCC->CFGR`.
2. **Deterministic Sampling**: Under the provided system clock (72 MHz or 64 MHz), configure TIM3 `PSC` and `ARR` to generate exactly 10,000 update events/sec.
3. **Master Mode Output**: Set `TIM3->CR2` MMS bits to `0b010` (Update event selected as TRGO).
4. **ADC Contract**:
   - PA0 configured as Analog Input (`CRL` MODE0=00, CNF0=00).
   - Sample time on Channel 0 set to 55.5 cycles (`SMPR2` SMP0 = 0b101).
   - Power up and execute full hardware calibration sequence (`RSTCAL`/`CAL`) with bounded timeouts.
   - Configure regular external trigger for `TIM3_TRGO` (`EXTSEL = 0b100`, `EXTTRIG = 1`).
   - Enable DMA generation in ADC (`ADC_CR2_DMA = 1`).
5. **DMA Contract**:
   - Fixed hardware channel: DMA1 Channel 1.
   - Destination: Persistent `g_acq_buffer` (128 elements, 16-bit half-words).
   - Circular mode (`CIRC = 1`), memory increment (`MINC = 1`), 16-bit peripheral and memory sizes.
   - Enable HT and TC interrupts; service and acknowledge flags in `DMA1_Channel1_IRQHandler`.
6. **Zero HAL**: Use only CMSIS direct register structs. No `HAL_` functions.

## Starter File
Implement your solution in `challenge/acquisition.c` adhering to `challenge/acquisition.h`.

## Validation
To test your implementation against the automated host and target suite:
```bash
bash challenge/validate.sh challenge
```
To run the complete verification suite including regression mutations:
```bash
bash challenge/verify_challenge.sh
```
