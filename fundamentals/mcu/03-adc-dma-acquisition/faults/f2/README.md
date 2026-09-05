# Fault Investigation: Fixture `f2`

## Observed Symptom
**Scenario-provided symptom (not author-captured evidence)**:
The acquisition timer is observed to be running, but `g_adc_buffer` remains completely unpopulated (all zeroes). Neither Half-Transfer nor Transfer-Complete interrupts ever trigger.

## Objective
Investigate the acquisition path from timer activity through ADC conversion and DMA transfer. Form 3–5 hypotheses, collect register evidence to isolate where progress stops, and provide a minimal fix.

## Allowed Tools
- Disassembly (`arm-none-eabi-objdump -d`)
- Symbol and ELF inspection (`arm-none-eabi-readelf`)
- Peripheral register inspection (`TIM3`, `ADC1`, `DMA1`)
- ST RM0008 Reference Manual

## Deliverables
1. Hypothesized root cause backed by register inspection evidence.
2. Peripheral register evidence that isolates the failing stage without assuming the root cause in advance.
3. Minimal source diff resolving the defect.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition/faults/f2 clean all
```
