# Fault Investigation: Fixture `f2`

## Observed Symptom
**Scenario-provided symptom (not author-captured evidence)**:
The acquisition timer is observed to be running, but `g_adc_buffer` remains completely unpopulated (all zeroes). Neither Half-Transfer nor Transfer-Complete interrupts ever trigger.

## Objective
Investigate peripheral trigger routing and acquisition sequencing. Collect register evidence to determine why hardware conversions are not being triggered, and provide a minimal fix.

## Allowed Tools
- Disassembly (`arm-none-eabi-objdump -d`)
- Symbol and ELF inspection (`arm-none-eabi-readelf`)
- Peripheral register inspection (`TIM3`, `ADC1`, `DMA1`)
- ST RM0008 Reference Manual

## Deliverables
1. Hypothesized root cause backed by register inspection evidence.
2. Peripheral register bit proof confirming the missing trigger connection.
3. Minimal source diff resolving the defect.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition/faults/f2 clean all
```
