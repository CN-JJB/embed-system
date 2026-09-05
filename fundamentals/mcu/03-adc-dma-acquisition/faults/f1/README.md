# Fault Investigation: Fixture `f1`

## Observed Symptom
When the firmware runs on target hardware at the canonical 72 MHz profile, the ADC produces noisy, highly erratic digital values. Linearity testing reveals severe integral non-linearity (INL) and missing codes, even with a stable DC potentiometer voltage on PA0.

## Objective
Identify the clock tree or ADC prescaler defect causing out-of-specification operation.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition/faults/f1 clean all
```
