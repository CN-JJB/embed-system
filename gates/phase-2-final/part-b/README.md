# Part B: Peripheral Register & DMA Data-Path Diagnosis

> **Time Budget:** 50 minutes  
> **Weight:** 25 points (Floor: 60% / $\ge 15.0$ points)  
> **Mode:** AI-Free (Strict)  

---

## 1. System Context & Observed Symptom

You are evaluating an autonomous peripheral acquisition pipeline on the STM32F103C8T6:
```text
Clock Tree (72 MHz SYSCLK, APB1=36 MHz, APB2=72 MHz, ADCPRE=/6 -> 12 MHz)
  -> TIM3 TRGO update event @ 10.0 kHz
  -> ADC1 regular conversion on PA0 (EXTSEL = 0b100, EXTTRIG = 1, SMP0 = 55.5 cycles)
  -> DMA1 Channel 1 circular transfer into 128-element 16-bit ping-pong buffer (g_adc_buffer)
  -> Half-Transfer (HT) and Transfer-Complete (TC) interrupts for double-buffering
```

The firmware builds cleanly with zero warnings (`-Wall -Wextra -Werror`).
When flashed to hardware (or simulated), the following symptom is reported:
* TIM3 is running and generating update events at 10.0 kHz.
* ADC1 receives triggers and executes conversions.
* DMA transfers execute and interrupt counters (`g_dma_ht_count`, `g_dma_tc_count`) advance continuously.
* **HOWEVER, inspection of `g_adc_buffer` reveals data integrity failure:** only the very first buffer entry (`g_adc_buffer[0][0]`) is continuously updated, while all subsequent array elements (`g_adc_buffer[0][1..63]`, `g_adc_buffer[1][0..63]`) remain completely unwritten (`0x0000`)!
* Downstream signal-processing algorithms receive constant zero vectors across the ping-pong buffers instead of full waveform records.

---

## 2. Deliverables & Investigation Tasks

1. **Clock & Rate Calculations:**
   Calculate and record:
   - APB1 timer clock frequency and TIM3 TRGO update rate from `PSC` and `ARR`.
   - APB2 clock, ADC prescaler `ADCPRE`, and resulting $f_{\text{ADCCLK}}$ ($\le 14\text{ MHz}$ constraint).
   - ADC sampling time $t_{\text{SMP}}$ (cycles and microseconds) and total conversion time $t_{\text{CONV}}$.
2. **Peripheral Register & Buffer Inspection:**
   Inspect the provided register and memory fixtures under `fixtures/`:
   - `fixtures/register_dump.txt` (pre-recorded register state labeled `SEEDED FIXTURE / ASSESSMENT INPUT`);
   - `fixtures/buffer_dump.txt` (memory dump of `g_adc_buffer`).
   *(If live hardware is available, capture equivalent live GDB register and memory dumps; otherwise document hardware status honestly as UNVERIFIED).*
3. **Observation, Interpretation & Non-Proof:**
   Provide a disciplined breakdown of what the register bits prove and do **not** prove.
4. **Root Cause Analysis:**
   Identify the specific bit in the peripheral configuration register responsible for preventing continuous automatic buffer reload.
5. **Minimal Principled Correction:**
   Modify `src/dma.c` to resolve the defect.
6. **Regression Verification:**
   Run `make check` to verify that the DMA configuration satisfies all hardware contract requirements.

---

## 3. Investigation Protocol

1. Build the seeded fixture:
   ```bash
   make clean && make
   ```
2. Run the automated check to observe the configuration failure:
   ```bash
   make check
   ```
3. Inspect `fixtures/register_dump.txt` and compare against ST RM0008 Section 10.4 (DMA) and Section 11 (ADC).
4. Record your answers in Section 5 of `../SUBMISSION_TEMPLATE.md`.
5. Apply the minimal fix in `src/dma.c` and verify with `make check`.
