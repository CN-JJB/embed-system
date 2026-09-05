# Fault Investigation: Fixture `f4`

## Observed Symptom
Firmware runs and DMA transfers start correctly. However, as soon as `init_acquisition()` exits and the main application begins calling subroutines or handling interrupts, the system crashes with a `HardFault` or local variables in deep stack frames are overwritten with ADC sensor readings!

## Objective
Identify the storage duration and lifetime violation of the buffer passed to `DMA1_Channel1->CMAR`.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition/faults/f4 clean all
```
