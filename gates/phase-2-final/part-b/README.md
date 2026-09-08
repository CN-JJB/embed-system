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
* The acquisition pipeline initially transfers the first 128 samples into `g_adc_buffer`.
* **HOWEVER, immediately after the first block completes, the acquisition stream halts completely:**
  - `g_dma_ht_count` and `g_dma_tc_count` increment exactly once (both freeze at 1).
  - Inspection of `DMA1_Channel1->CNDTR` reads `0x00000000`.
  - No further DMA transfers or buffer updates occur despite TIM3 and ADC1 continuing to trigger.
  - Downstream digital signal processing algorithms starve after consuming the initial block.

---

## 2. Deliverables & Investigation Tasks

1. **Clock & Rate Calculations:**
   Calculate and record:
   - APB1 timer clock frequency and TIM3 TRGO update rate from `PSC` and `ARR`.
   - APB2 clock, ADC prescaler `ADCPRE`, and resulting $f_{\text{ADCCLK}}$ ($\le 14\text{ MHz}$ constraint).
   - ADC sampling time $t_{\text{SMP}}$ (cycles and microseconds) and total conversion time $t_{\text{CONV}}$.
2. **Peripheral Register & Buffer Inspection:**
   Inspect the provided register and memory fixtures under `fixtures/`:
   - `fixtures/register_dump.txt` (supplied assessment input labeled `SCRIPTED / SEEDED ASSESSMENT FIXTURE — NOT LIVE HARDWARE EVIDENCE`);
   - `fixtures/buffer_dump.txt` (memory dump of `g_adc_buffer`).
   *(If live hardware is available, capture equivalent live GDB register and memory dumps; otherwise document hardware status honestly as UNVERIFIED).*
3. **Observation, Interpretation & Non-Proof:**
   Provide a disciplined breakdown of what the register bits prove and do **not** prove.
4. **Root Cause Analysis:**
   Identify the configuration and state-transition defect in `DMA1_Channel1->CCR` responsible for the channel halting after the first transfer block rather than continuing continuous double-buffered acquisition; justify from ST RM0008 Section 10.4.
5. **Minimal Principled Correction:**
   Modify `src/dma.c` to resolve the data-path defect.
6. **Verify Artifact & Build Integrity:**
   Rebuild the firmware and run `make check` to confirm valid compilation and artifact generation. (Note: `make check` validates generic artifact integrity; technical evaluation of the peripheral configuration contract is performed by reviewer-isolated testing).

---

## 3. Investigation Protocol

1. Build the seeded fixture:
   ```bash
   make clean && make
   ```
2. Run `make check` to verify initial build integrity:
   ```bash
   make check
   ```
3. Inspect `fixtures/register_dump.txt` and `fixtures/buffer_dump.txt` and compare against ST RM0008 Section 10.4 (DMA) and Section 11 (ADC).
4. Record your answers in Section 5 of `../SUBMISSION_TEMPLATE.md`.
5. Apply the minimal fix in `src/dma.c` and verify build integrity with `make check`.
