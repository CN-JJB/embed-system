# P2-M03 Fault Analysis & Diagnostic Guides (Fixtures f1–f5)

This document provides evaluator analysis, register proofs, hypothesis trees, and minimal fixes for the five controlled learner fault fixtures in `fundamentals/mcu/03-adc-dma-acquisition/faults/`.

---

## Fixture `f1`: Out-of-Spec ADC Clock Prescaler (`ADCPRE = /2`)

### 1. Symptom & Evidence
- **Scenario-Provided Symptom**: When running at the canonical 72 MHz clock profile, sampled ADC conversion readings appear noisy and unstable.
- **Authoritative Register / Specification Proof**:
  Register inspection shows `RCC->CFGR` bits [15:14]:
  ```text
  (EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED)
  RCC->CFGR & RCC_CFGR_ADCPRE == 0x0000 (Divide by 2)
  ```
  At SYSCLK = PCLK2 = 72 MHz, $f_{\text{ADCCLK}} = \frac{72\text{ MHz}}{2} = 36\text{ MHz}$.
  According to ST RM0008 Section 11.2 and DS5319 Section 5.3.18, $f_{\text{ADC}} \le 14\text{ MHz}$ under all operating conditions. Operating the ADC SAR comparator and sampling logic at 36 MHz violates the rated operating envelope by a factor of 2.57.
  *Note on symptoms*: The contract violation is that ADCCLK exceeds the rated $\le 14\text{ MHz}$ limit. Outside this limit, comparator settling and conversion accuracy are undefined by the manufacturer; specific symptoms (such as non-linearity or noise) are silicon-, temperature-, and impedance-dependent rather than a portable deterministic promise.
- **Minimal Fix**:
  ```diff
  - RCC->CFGR |= RCC_CFGR_ADCPRE_DIV2;
  + RCC->CFGR |= RCC_CFGR_ADCPRE_DIV6;
  ```
  With `/6`, $f_{\text{ADCCLK}} = 12\text{ MHz} \le 14\text{ MHz}$.

---

## Fixture `f2`: Trigger Routing Misconfiguration (`EXTSEL = TIM1_CC1`)

### 1. Symptom & Evidence
- **Scenario-Provided Symptom**: TIM3 is observed running, but `g_adc_buffer` is unpopulated (all zeroes) and no DMA interrupts fire.
- **Register Proof**:
  ```text
  (EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED)
  (gdb) p/x (ADC1->CR2 >> 17) & 0x7
  $1 = 0x0   # 0b000 corresponds to TIM1_CC1 per RM0008 Table 65
  ```
  Because TIM1 is unclocked and unused in this application, no external trigger edges are ever delivered to ADC1, so no regular conversions occur.
- **Minimal Fix**:
  ```diff
  - ADC1->CR2 &= ~ADC_CR2_EXTSEL;
  + ADC1->CR2 &= ~ADC_CR2_EXTSEL;
  + ADC1->CR2 |= ADC_CR2_EXTSEL_2; /* 0b100 = TIM3_TRGO */
  ```

---

## Fixture `f3`: DMA Transfer-Width Mismatch (`MSIZE = 8-bit`)

### 1. Symptom & Evidence
- **Scenario-Provided Symptom**: The acquisition pipeline runs and interrupts trigger, but inspecting destination memory when interpreted as `uint16_t` samples reveals corrupted, misaligned readings.
- **Register Proof**:
  ```text
  (EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED)
  (gdb) p/x (DMA1_Channel1->CCR >> 14) & 0x3
  $1 = 0x0   # MSIZE = 00 (8-bit)
  (gdb) p/x (DMA1_Channel1->CCR >> 8) & 0x3
  $2 = 0x1   # PSIZE = 01 (16-bit)
  ```
- **Hardware Mechanism (RM0008 Section 13.3.5)**:
  - When peripheral transfer width is 16-bit (`PSIZE=01`) and memory transfer width is 8-bit (`MSIZE=00`), the DMA controller reads 16 bits from `ADC1->DR`, discards/truncates the upper 8 bits (`[15:8]`), and writes only the low byte (`[7:0]`) to memory.
  - The memory pointer increment (`MINC`) follows `MSIZE`, advancing by **1 byte** per transfer.
  - A block of 128 transfers performs 128 8-bit writes, writing 128 bytes total into memory (which covers only half of a 256-byte `uint16_t[128]` array).
  - When the software interprets this memory as `uint16_t` items, adjacent byte writes are paired together (transfer 0 as low byte, transfer 1 as high byte, etc.). The observable values are byte-packed and mispaired across consecutive conversions, rather than having the upper byte zeroed in each 16-bit word.
- **Minimal Fix**:
  ```diff
  - DMA1_Channel1->CCR = DMA_CCR_CIRC | DMA_CCR_MINC | DMA_CCR_PSIZE_0;
  + DMA1_Channel1->CCR = DMA_CCR_CIRC | DMA_CCR_MINC | DMA_CCR_PSIZE_0 | DMA_CCR_MSIZE_0;
  ```

---

## Fixture `f4`: Persistent-Buffer Lifetime Violation (Local Stack Allocation)

### 1. Symptom & Evidence
- **Scenario-Provided Symptom**: Initial acquisition starts, but after the initialization function returns, memory corruption or HardFault exceptions occur when subsequent subroutines execute.
- **Register & Memory Proof**:
  ```text
  (EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED)
  (gdb) p/x DMA1_Channel1->CMAR
  $1 = 0x20004fb0   # CMAR points into the active stack region near _estack
  ```
  `local_stack_buffer` was allocated with automatic storage duration inside `init_acquisition_with_stack_buffer()`. When that function returned, its stack frame was reclaimed. Subsequent subroutine calls place active stack frames across `0x20004fb0`, which the asynchronous DMA controller continuously overwrites.
- **Minimal Fix**:
  Move buffer to static storage duration (e.g. file-scope `static volatile uint16_t`):
  ```diff
  - void init_acquisition_with_stack_buffer(void) {
  -     uint16_t local_stack_buffer[128];
  + static volatile uint16_t s_persistent_buffer[128];
  + void init_acquisition_with_stack_buffer(void) {
  -     DMA1_Channel1->CMAR = (uint32_t)local_stack_buffer;
  +     DMA1_Channel1->CMAR = (uint32_t)s_persistent_buffer;
  ```

---

## Fixture `f5`: Omission of ADC DMA Request Enable (`ADC_CR2_DMA`)

### 1. Symptom & Evidence
- **Scenario-Provided Symptom**: TIM3 updates fire and ADC1 converts (EOC flag asserts in `ADC1->SR`), but DMA never transfers data and `CNDTR` remains at 128.
- **Register Proof**:
  ```text
  (EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED)
  (gdb) p/x ADC1->CR2 & (1 << 8)
  $1 = 0x0   # ADC_CR2_DMA (bit 8) is 0
  ```
  Although conversions occur at 10 kHz, ADC1 is not configured to signal the DMA1 controller upon conversion completion.
- **Minimal Fix**:
  ```diff
  - ADC1->CR2 |= ADC_CR2_EXTSEL_2 | ADC_CR2_EXTTRIG;
  + ADC1->CR2 |= ADC_CR2_EXTSEL_2 | ADC_CR2_EXTTRIG | ADC_CR2_DMA;
  ```
