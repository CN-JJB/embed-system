# Fault Investigation: Fixture `f3`

## Observed Symptom
**Scenario-provided symptom (not author-captured evidence)**:
The circular acquisition path runs and interrupts trigger, but inspecting destination memory when interpreted as an array of `uint16_t` conversion samples reveals corrupted, misaligned data. The buffer also appears to advance through memory at an unexpected byte stride.

## Objective
Investigate the DMA controller configuration and destination memory layout. Formulate a hypothesis, collect register evidence, explain the hardware transfer width and address increment behavior, and provide a minimal fix.

## Allowed Tools
- Disassembly (`arm-none-eabi-objdump -d`)
- Symbol and ELF inspection (`arm-none-eabi-readelf`)
- Peripheral register inspection (`DMA1`)
- ST RM0008 Reference Manual Section 13 (DMA programmable data width)

## Deliverables
1. Hypothesized root cause backed by register inspection evidence.
2. Technical explanation of how transfer width affects destination memory addressing and data alignment.
3. Minimal source diff resolving the defect.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition/faults/f3 clean all
```
