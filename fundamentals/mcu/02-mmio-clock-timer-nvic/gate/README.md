# P2-M02 Module Gate: Clock Tree & Interrupt Fault Recovery

> **Assessment Mode**: AI-Free (Strict). Official ST RM0008, PM0056, and CMSIS documentation permitted.  
> **Target Mastery**: L4-local register/MMIO interaction, L3 NVIC handling.  
> **Time Limit**: 50 minutes.

## Mission
You are provided with a non-functioning bare-metal firmware image in [`gate_fault_firmware/`](gate_fault_firmware/).
The firmware compiles without error. **EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED:** on target, PA1 should show a single initial edge transition and then stop toggling; `g_tim2_ticks` should stop at 1 while Thread mode remains responsive.

## Deliverables
1. Articulate the observed symptoms.
2. Formulate 3-5 hypotheses before editing code.
3. Collect evidence via register dumps and disassembly (`RCC`, `TIM2`, `NVIC`).
4. Identify the root cause in the timer-lifecycle and control register family.
5. Apply the minimal fix. Use `make check` for static/binary regression, then record target timing separately when hardware is available; physical 1.0 ms event timing remains UNVERIFIED until measured.
