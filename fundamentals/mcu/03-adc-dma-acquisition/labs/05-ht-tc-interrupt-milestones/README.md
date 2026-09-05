# Lab 05: Half-Transfer (HT) and Transfer-Complete (TC) Interrupt Milestones & Ownership

## Objective
Enable Half-Transfer (HT) and Transfer-Complete (TC) interrupts on DMA1 Channel 1, establish a ping-pong buffer ownership model between DMA hardware and the CPU, and output physical timing pulses on PA3 and PA4.

## Prerequisites
- Lab 01 to Lab 04.
- Cortex-M3 NVIC priority configuration (P2-M02).

## Environment
- Target: STM32F103C8T6.
- Toolchain: Arm GNU Toolchain 13.3.rel1 / Ubuntu GCC 13.2.1.
- Measurement: 2-channel oscilloscope or logic analyzer connected to PA3 (HT) and PA4 (TC).

## Estimated Time
- 45 minutes (MUST load).

## AI Mode
- **AI-Hint**: Socratic guidance on event frequencies vs toggle frequencies.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition clean all
```

## Procedure
1. Configure DMA Interrupt Enables in `DMA1_Channel1->CCR`:
   - `HTIE = 1` (Half-Transfer Interrupt Enable).
   - `TCIE = 1` (Transfer Complete Interrupt Enable).
   - `TEIE = 1` (Transfer Error Interrupt Enable).
2. Configure NVIC:
   - `NVIC_SetPriority(DMA1_Channel1_IRQn, 5);`
   - `NVIC_EnableIRQ(DMA1_Channel1_IRQn);`
3. Implement `DMA1_Channel1_IRQHandler()`:
   ```c
   void DMA1_Channel1_IRQHandler(void) {
       uint32_t isr = DMA1->ISR;
       if (isr & DMA_ISR_HTIF1) {
           DMA1->IFCR = DMA_IFCR_CHTIF1;   /* Clear HT flag */
           GPIOA->BSRR = (1 << 3);          /* PA3 HIGH */
           g_dma_ht_count++;
           /* CPU owns Half 0: process g_adc_buffer[0][0..63] */
           GPIOA->BRR = (1 << 3);           /* PA3 LOW (pulse) */
       }
       if (isr & DMA_ISR_TCIF1) {
           DMA1->IFCR = DMA_IFCR_CTCIF1;   /* Clear TC flag */
           GPIOA->BSRR = (1 << 4);          /* PA4 HIGH */
           g_dma_tc_count++;
           /* CPU owns Half 1: process g_adc_buffer[1][0..63] */
           GPIOA->BRR = (1 << 4);           /* PA4 LOW (pulse) */
       }
       if (isr & DMA_ISR_TEIF1) {
           DMA1->IFCR = DMA_IFCR_CTEIF1;
           g_dma_te_count++;
       }
       __DSB();
   }
   ```
4. Double-Buffering Ownership Contract:
   - **Phase 1 (Samples 0..63)**: DMA writes `g_adc_buffer[0]`. CPU must not access `g_adc_buffer[0]`.
   - **HT Interrupt**: DMA finishes sample 63, asserts `HTIF1`, and immediately begins writing `g_adc_buffer[1]`.
   - **Phase 2 (Samples 64..127)**: DMA writes `g_adc_buffer[1]`. CPU owns `g_adc_buffer[0]` and computes statistics.
   - **TC Interrupt**: DMA finishes sample 127, asserts `TCIF1`, wraps to index 0, and begins writing `g_adc_buffer[0]`.
   - **Phase 3**: CPU owns `g_adc_buffer[1]`.

## Event Rate vs Toggle Frequency Mathematics
- Sampling frequency $f_s = 10,000\text{ samples/sec}$.
- Total buffer capacity = 128 samples (64 per half).
- Milestone interval:
  $$T_{\text{half}} = \frac{64\text{ samples}}{10,000\text{ samples/sec}} = 6.4\text{ ms}$$
  $$T_{\text{full}} = \frac{128\text{ samples}}{10,000\text{ samples/sec}} = 12.8\text{ ms}$$
- Therefore, each HT event occurs every $12.8\text{ ms}$, and each TC event occurs every $12.8\text{ ms}$:
  $$f_{\text{event}} = \frac{10,000}{128} = 78.125\text{ events/sec}$$
- **Observable Timing**:
  - Emitting a short pulse per event on PA3/PA4 produces a **78.125 Hz pulse repetition rate**.
  - If toggling a pin on each event (inverting level), the period is $2 \times 12.8\text{ ms} = 25.6\text{ ms}$, producing a **39.0625 Hz square wave**.

## Expected Observation
- Logic analyzer or oscilloscope on PA3 (HT) and PA4 (TC):
  - PA3 pulses at exactly 78.125 Hz (period 12.8 ms).
  - PA4 pulses at exactly 78.125 Hz, phase-shifted by 6.4 ms relative to PA3.
- In GDB:
  - Both `g_dma_ht_count` and `g_dma_tc_count` increment at 78 counts per second.

## Actual Verification Status
- **Static & Disassembly Verification**: **VERIFIED** on host cross-compiler.
- **Physical Waveform Capture**: **UNVERIFIED** (No oscilloscope attached to headless host).

## Questions
1. Why is the toggle square wave frequency (39.0625 Hz) exactly half of the event repetition rate (78.125 Hz)?
2. If processing Half 0 in software takes 7.0 ms, what happens to the buffer contents?

## Failure Modes
- Forgetting `__DSB()` after clearing `IFCR`, causing an extra phantom interrupt entry due to Cortex-M3 write buffering.
- Buffer overflow / overrun if CPU processing exceeds the $6.4\text{ ms}$ half-buffer window.

## Debug Strategy
- Check `DMA1->ISR` bits [3:0] in GDB to verify `HTIF1`, `TCIF1`, and `TEIF1`.
- Verify `DMA1_Channel1_IRQn` priority in `NVIC->IP`.

## Challenge
Add an overrun detection check: if a new HT interrupt arrives before CPU processing of the previous half is finished, flag an error LED.

## Cleanup
Completed acquisition pipeline ready for diagnostic fault experiments in Lab 06.

## Sources
- ST RM0008 Rev 21, Section 13.4.1 (DMA interrupt status register).
- ST PM0056 Rev 7, Section 4.3 (NVIC programming).
