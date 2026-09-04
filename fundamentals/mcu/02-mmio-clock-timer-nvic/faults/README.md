# P2-M02 Fault Competency Fixtures

This directory houses reproducible, evidence-driven firmware fixtures covering the primary hardware/software fault families in the MMIO, clock, timer, and NVIC domains.

| Fixture | Fault Family | Observable Symptom | Evidence Channel |
|---|---|---|---|
| [`fault1_clock_not_enabled/`](fault1_clock_not_enabled/) | Peripheral clock gating | Timer registers read as 0 or write is ignored; counter never advances | `print /x RCC->APB1ENR`, `print /x TIM2->CR1` in GDB |
| [`fault2_flag_not_cleared/`](fault2_flag_not_cleared/) | Interrupt lifecycle / flag acknowledge | Main thread completely halts; CPU trapped in infinite ISR loop (Interrupt Storm) | GDB backtrace halts in `TIM2_IRQHandler`, `TIM2->SR` bit 0 never clears |
| [`fault3_timer_clock_math/`](fault3_timer_clock_math/) | Clock tree assumption error | Timer fires at 2x expected rate (500 us instead of 1.0 ms) | Logic analyzer / oscilloscope frequency measurement; `RCC->CFGR` APB1 prescaler audit |
| [`fault4_nvic_priority_error/`](fault4_nvic_priority_error/) | NVIC priority encoding | High-priority task starved by low-priority interrupt; unexpected preemption | Direct memory read of NVIC priority byte (`0xE000E400 + IRQn`) |
| [`fault5_rmw_hazard/`](fault5_rmw_hazard/) | Concurrency race on MMIO register | Erratic missing pulses, output pin glitching under interrupt load | Disassembly audit (`LDR/ORR/STR` on `ODR`); logic analyzer trace |

## Verification & Disclosure Rule
- Learner-facing files state the symptoms and provide reproduction commands.
- Learner-facing files **do not** reveal the exact line or root cause.
- Complete hypothesis-driven root-cause analyses and solutions are cataloged in [`../reviewer/fault_analysis.md`](../reviewer/fault_analysis.md).
