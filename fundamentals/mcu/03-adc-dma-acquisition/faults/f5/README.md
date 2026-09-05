# Fault Investigation: Fixture `f5`

## Observed Symptom
**Scenario-provided symptom (not author-captured evidence)**:
Periodic timer triggers are active and ADC status indications show conversion activity, but the DMA transfer count register does not decrement from its initial value and no data arrives in `g_adc_buffer`.

## Objective
Investigate peripheral signaling and handshake configuration between the ADC and the DMA controller. Formulate a hypothesis, collect register evidence explaining why transfers are not initiated, and provide a minimal fix.

## Allowed Tools
- Disassembly (`arm-none-eabi-objdump -d`)
- Symbol and ELF inspection (`arm-none-eabi-readelf`)
- Peripheral register inspection (`ADC1`, `DMA1`)
- ST RM0008 Reference Manual (ADC and DMA interconnection)

## Deliverables
1. Hypothesized root cause backed by register inspection evidence.
2. Register bit analysis explaining the missing transfer initiation signal.
3. Minimal source diff resolving the defect.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition/faults/f5 clean all
```
