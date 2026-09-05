#ifndef ADC_H
#define ADC_H

#include <stdint.h>
#include <stdbool.h>

/* Bounded ADC calibration return codes */
#define ADC_INIT_OK                     0
#define ADC_INIT_ERR_RSTCAL_TIMEOUT    -1
#define ADC_INIT_ERR_CAL_TIMEOUT       -2

/**
 * @brief Initialize ADC1 for hardware-triggered conversion via TIM3 TRGO.
 *
 * Configures:
 *  - RCC APB2 clock gate for ADC1 and GPIOA.
 *  - ADCPRE = /6 (yielding 12 MHz ADCCLK at 72 MHz, 10.67 MHz at 64 MHz, <= 14 MHz ceiling).
 *  - PA0 as Analog input (CNF=00, MODE=00).
 *  - Channel 0 sample time = 55.5 cycles (SMP0 = 0b101).
 *  - Regular sequence length = 1 conversion, channel 0.
 *  - Power-up stabilization and hardware calibration sequence (RSTCAL/CAL) with bounded timeouts.
 *  - External regular trigger on TIM3 TRGO (EXTSEL = 0b100, EXTTRIG = 1).
 *  - ADC DMA request generation (DMA = 1).
 *
 * @param pclk2_hz Active APB2 peripheral clock in Hz.
 * @return ADC_INIT_OK (0) on success, negative error code on calibration timeout.
 */
int adc_init(uint32_t pclk2_hz);

/**
 * @brief Decode active ADCCLK frequency from RCC registers.
 *
 * @param pclk2_hz Active APB2 clock in Hz.
 * @return Decoded ADCCLK in Hz.
 */
uint32_t adc_get_clock_hz(uint32_t pclk2_hz);

#endif /* ADC_H */
