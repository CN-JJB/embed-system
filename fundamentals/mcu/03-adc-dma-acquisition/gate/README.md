# P2-M03 Module Gate: Peripheral Acquisition Diagnostic Transfer Exam

> Mode: **AI-Free (Strict)**  
> Time Limit: **60 minutes**  
> Authorized References: ST RM0008 Rev 21, ST DS5319 Rev 20, ST PM0056 Rev 7, CMSIS device headers.  
> AI Policy: Strict AI-Free. No LLMs, Copilot, or automated assistants.

---

## Scenario
You are handed a board running newly deployed firmware in `gate/gate_fault_firmware/`. The firmware is intended to perform continuous 10 kHz circular acquisition of an analog sensor on PA0 into a double buffer.

However, field testing reports:
- The firmware compiles without warnings and links cleanly.
- The system powers up, but **no pulses are ever observed on PA3 (HT) or PA4 (TC)**.
- Reading `DMA1_Channel1->CNDTR` in GDB shows that the transfer counter remains completely motionless at its initial value (128).
- The ADC configuration registers indicate that ADC1 is powered on (`ADON=1`), calibrated, and configured for TIM3 TRGO external trigger with DMA enabled.
- The TIM3 counter register (`TIM3->CNT`) is observed to be incrementing and wrapping.

---

## Diagnostic Deliverables
Follow the canonical hypothesis-driven investigation protocol:

1. **Symptom Description**: Re-state the observed behavior in your own words.
2. **Hypotheses (3–5 minimum)**: Articulate competing explanations for why DMA transfers never begin despite an active timer counter and powered ADC.
3. **Evidence Collection Plan**: Specify exact register addresses and bitfields to inspect in GDB or disassembly.
4. **Root Cause Identification**: Identify the exact configuration defect preventing trigger propagation.
5. **Minimal Corrective Patch**: Produce a minimal diff resolving the root cause without rewriting unaffected subsystems.
6. **Verification & Regression**: Verify that `CNDTR` decrements and milestone pulses appear on PA3/PA4.
