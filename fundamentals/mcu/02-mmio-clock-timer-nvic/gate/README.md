# P2-M02 Module Gate: Clock Tree & Interrupt Fault Recovery

> **Assessment Mode**: AI-Free (Strict). Official ST RM0008, PM0056, and CMSIS documentation permitted.  
> **Target Mastery**: L4-local register/MMIO interaction, L3 NVIC handling.  
> **Time Limit**: 50 minutes.

## Mission
You are provided with a non-functioning bare-metal firmware image in [`gate_fault_firmware/`](gate_fault_firmware/).
The firmware compiles without error, but the timer interrupt triggers at an erratic frequency and the main loop hangs.

## Deliverables
1. Articulate the observed symptoms.
2. Formulate 3-5 hypotheses before editing code.
3. Collect evidence via GDB register dumps (`RCC`, `FLASH`, `TIM2`, `NVIC`).
4. Identify the root causes in the clock-tree / interrupt-lifecycle family.
5. Apply the minimal fix and verify deterministic 1.0 ms timing using `make check`.
