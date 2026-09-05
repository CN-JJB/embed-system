# Fault Investigation: Fixture `f4`

## Observed Symptom
**Scenario-provided symptom (not author-captured evidence)**:
Initial acquisition begins normally, but after the initialization sequence completes and subsequent subroutines execute, unexpected system crashes or memory corruption in unrelated variables is observed.

## Objective
Trace the destination memory buffer address and storage duration across the firmware lifecycle. Formulate a hypothesis, collect evidence from symbol and register state, identify the memory corruption mechanism, and provide a minimal fix.

## Allowed Tools
- Disassembly (`arm-none-eabi-objdump -d`)
- Symbol table and section inspection (`arm-none-eabi-readelf -s -S`, `nm`)
- DMA address register inspection (`DMA1_Channel1->CMAR`) vs linker script memory regions
- Memory map and calling convention analysis

## Deliverables
1. Hypothesized root cause backed by memory and symbol evidence.
2. Technical explanation of the storage duration violation.
3. Minimal source diff resolving the defect.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition/faults/f4 clean all
```
