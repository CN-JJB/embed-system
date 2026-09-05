# Fault Investigation: Fixture `f3`

## Observed Symptom
The circular acquisition path runs and interrupts fire, but inspecting the 16-bit array `g_adc_buffer` reveals corrupted values. Half of each 16-bit entry appears to contain zero, and high-byte conversion data is lost or misaligned. The buffer also appears to advance through memory twice as slowly.

## Objective
Analyze the DMA channel configuration register (`CCR`) data-size definitions and explain why memory sizing must match peripheral sizing.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition/faults/f3 clean all
```
