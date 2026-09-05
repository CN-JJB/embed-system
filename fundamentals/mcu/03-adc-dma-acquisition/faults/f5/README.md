# Fault Investigation: Fixture `f5`

## Observed Symptom
TIM3 is firing 10 kHz update triggers, and ADC1 converts samples as verified by the `EOC` flag in `ADC1->SR`. However, `DMA1_Channel1->CNDTR` never decrements from its initial value of 128, and no data is transferred to `g_adc_buffer`.

## Objective
Diagnose why the peripheral (ADC1) is not asserting DMA request signals to the DMA1 controller despite ongoing analog conversions.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition/faults/f5 clean all
```
