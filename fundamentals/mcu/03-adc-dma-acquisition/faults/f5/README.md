# Fault Investigation: Fixture `f5`

## Observed Symptom
**Scenario-provided symptom (not author-captured evidence)**:
Periodic timer triggers are active and ADC status indications show conversion activity, but the DMA transfer count register does not decrement from its initial value and no data arrives in `g_adc_buffer`.

## Objective
Investigate why the acquisition path reaches ADC conversion activity but not DMA progress. Formulate 3–5 hypotheses, collect register evidence across ADC/DMA state, and provide a minimal fix.

## Allowed Tools
- Disassembly (`arm-none-eabi-objdump -d`)
- Symbol and ELF inspection (`arm-none-eabi-readelf`)
- Peripheral register inspection (`ADC1`, `DMA1`)
- ST RM0008 Reference Manual (ADC and DMA interconnection)

## Deliverables
1. Hypothesized root cause backed by register inspection evidence.
2. Register evidence proving the failing request/transfer boundary.
3. Minimal source diff resolving the defect.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition/faults/f5 clean all
```
