# Fault Investigation: Fixture `f2`

## Observed Symptom
TIM3 is observed to be running, but `g_adc_buffer` remains completely unpopulated (all zeroes). Neither Half-Transfer nor Transfer-Complete interrupts ever trigger.

## Objective
Trace the peripheral trigger interconnection between the timer and the ADC to discover why hardware conversions are never initiated.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition/faults/f2 clean all
```
