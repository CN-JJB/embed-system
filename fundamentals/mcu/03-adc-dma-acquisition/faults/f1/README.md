# Fault Investigation: Fixture `f1`

## Observed Symptom
**Scenario-provided symptom (not author-captured evidence)**:
When the firmware runs under the 72 MHz system clock profile, sampled ADC conversion values appear noisy and unstable even with a constant DC voltage applied to PA0.

## Objective
Investigate peripheral clocking and analog subsystem configuration. Formulate a hypothesis, collect register evidence, identify any operating parameter violation against the microcontroller specification, and implement a minimal fix.

## Allowed Tools
- Disassembly (`arm-none-eabi-objdump -d`)
- Symbol and ELF inspection (`arm-none-eabi-readelf`)
- Static register inspection and datasheet/reference manual analysis (`RCC`, `ADC1`)
- ST RM0008 Reference Manual and STM32F103xB Datasheet

## Deliverables
1. Hypothesized root cause backed by register inspection evidence.
2. Authoritative specification citation for any contract violation.
3. Minimal source diff resolving the defect.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition/faults/f1 clean all
```
