# P2-M03 Fault Analysis & Diagnostic Guides (Fixtures f1–f5)

This document provides evaluator analysis, register proofs, hypothesis trees, and minimal fixes for the five controlled learner fault fixtures in `fundamentals/mcu/03-adc-dma-acquisition/faults/`.

---

## Fixture `f1`: Out-of-Spec ADC Clock Prescaler (`ADCPRE = /2`)

### 1. Symptom & Evidence
- **Symptom**: Erratic readings, high analog noise, non-linearity, and missing codes.
- **Register Proof**: Disassembly or GDB inspects `RCC->CFGR` bits [15:14]:
  ```text
  RCC->CFGR & RCC_CFGR_ADCPRE == 0x0000 (Divide by 2)
  ```
  At SYSCLK/PCLK2 = 72 MHz, $f_{\text{ADCCLK}} = 36\text{ MHz}$.
  According to ST RM0008 Section 11 and DS5319 Section 5.3.18, $f_{\text{ADC}} \le 14\text{ MHz}$. Running the ADC SAR logic at 36 MHz exceeds internal comparator stabilization limits, destroying conversion accuracy.
- **Minimal Fix**:
  ```diff
  - RCC->CFGR |= RCC_CFGR_ADCPRE_DIV2;
  + RCC->CFGR |= RCC_CFGR_ADCPRE_DIV6;
  ```

---

## Fixture `f2`: Trigger Routing Misconfiguration (`EXTSEL = TIM1_CC1`)

### 1. Symptom & Evidence
- **Symptom**: TIM3 runs, ADC initialized, but `g_adc_buffer` is unpopulated and no interrupts fire.
- **Register Proof**:
  ```gdb
  (gdb) p/x (ADC1->CR2 >> 17) & 0x7
  $1 = 0x0   # 0b000 corresponds to TIM1_CC1 per RM0008 Table 65!
  ```
  Since TIM1 is unclocked and unused, no trigger edges are ever received by ADC1.
- **Minimal Fix**:
  ```diff
  - ADC1->CR2 &= ~ADC_CR2_EXTSEL;
  + ADC1->CR2 &= ~ADC_CR2_EXTSEL;
  + ADC1->CR2 |= ADC_CR2_EXTSEL_2; /* 0b100 = TIM3_TRGO */
  ```

---

## Fixture `f3`: DMA Transfer-Width Mismatch (`MSIZE = 8-bit`)

### 1. Symptom & Evidence
- **Symptom**: 16-bit buffer contains byte-packed truncated readings; upper 8 bits lost.
- **Register Proof**:
  ```gdb
  (gdb) p/x (DMA1_Channel1->CCR >> 14) & 0x3
  $1 = 0x0   # MSIZE = 00 (8-bit)
  (gdb) p/x (DMA1_Channel1->CCR >> 8) & 0x3
  $2 = 0x1   # PSIZE = 01 (16-bit)
  ```
  RM0008 Section 13.3.5 Table 76 states: when peripheral size is 16-bit and memory size is 8-bit, bits [15:8] of the peripheral register are dropped!
- **Minimal Fix**:
  ```diff
  - DMA1_Channel1->CCR = DMA_CCR_CIRC | DMA_CCR_MINC | DMA_CCR_PSIZE_0;
  + DMA1_Channel1->CCR = DMA_CCR_CIRC | DMA_CCR_MINC | DMA_CCR_PSIZE_0 | DMA_CCR_MSIZE_0;
  ```

---

## Fixture `f4`: Persistent-Buffer Lifetime Violation (Local Stack Allocation)

### 1. Symptom & Evidence
- **Symptom**: Unpredictable memory corruption or HardFault after initialization function returns.
- **Register & Memory Proof**:
  ```gdb
  (gdb) p/x DMA1_Channel1->CMAR
  $1 = 0x20004fb0   # CMAR points directly into the active stack region near _estack!
  ```
  `local_stack_buffer` was allocated on the stack inside `init_acquisition_with_stack_buffer()`. When that function returned, its stack space was reclaimed. Subsequent subroutine calls place stack frames across `0x20004fb0`, which active DMA streams overwrite!
- **Minimal Fix**:
  Move buffer to file-scope static storage duration:
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
- **Symptom**: TIM3 fires, ADC converts (EOC flag asserts in `ADC1->SR`), but DMA never transfers and `CNDTR` stays at 128.
- **Register Proof**:
  ```gdb
  (gdb) p/x ADC1->CR2 & (1 << 8)
  $1 = 0x0   # ADC_CR2_DMA (bit 8) is 0!
  ```
  Although ADC conversions occur at 10 kHz, the ADC is not configured to signal the DMA1 controller on conversion completion.
- **Minimal Fix**:
  ```diff
  - ADC1->CR2 |= ADC_CR2_EXTSEL_2 | ADC_CR2_EXTTRIG;
  + ADC1->CR2 |= ADC_CR2_EXTSEL_2 | ADC_CR2_EXTTRIG | ADC_CR2_DMA;
  ```
