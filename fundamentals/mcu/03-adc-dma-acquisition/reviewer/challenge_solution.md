# P2-M03 Challenge Solution & Pedagogical Guide

## Architectural Invariants
1. **Clock Safety**: In `RCC->CFGR`, `ADCPRE` must be set to `0b10` (`RCC_CFGR_ADCPRE_DIV6`), ensuring $f_{\text{ADCCLK}} = 12\text{ MHz} \le 14\text{ MHz}$ at 72 MHz (and $\approx 10.67\text{ MHz}$ at 64 MHz).
2. **Deterministic Sampling**: Under `sysclk_hz`, `PSC = (sysclk_hz / 1,000,000) - 1` and `ARR = 99`, generating an update event every $100\ \mu\text{s}$ (10 kHz).
3. **Trigger Chain**:
   - `TIM3->CR2` MMS bits [6:4] = `0b010` (Update event selected as TRGO).
   - `ADC1->CR2` EXTSEL bits [19:17] = `0b100` (TIM3_TRGO).
   - `ADC1->CR2` EXTTRIG bit 20 = `1` (Enable external trigger for regular channels).
   - `ADC1->CR2` DMA bit 8 = `1` (Enable DMA request generation).
4. **DMA Configuration**:
   - Fixed mapping: DMA1 Channel 1.
   - `CPAR` = `&ADC1->DR`.
   - `CMAR` = `(uint32_t)g_acq_buffer` (must have static storage duration).
   - `CNDTR` = 128 (64 half-words per buffer half).
   - `CCR` bits: `CIRC=1`, `MINC=1`, `PSIZE=01`, `MSIZE=01`, `HTIE=1`, `TCIE=1`, `EN=1`.
5. **Interrupt & Event Rate**:
   - 10 ksample/s / 128 samples per cycle = **78.125 events/sec**.
   - Pulse repetition rate = 78.125 Hz.
   - Toggle frequency = 39.0625 Hz.
