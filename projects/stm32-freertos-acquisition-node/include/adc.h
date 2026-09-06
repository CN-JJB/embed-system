#ifndef ADC_H
#define ADC_H

#include <stdint.h>
#include <stdbool.h>

#define ADC_INIT_OK                     0
#define ADC_INIT_ERR_RSTCAL_TIMEOUT    -1
#define ADC_INIT_ERR_CAL_TIMEOUT       -2

/**
 * @brief Initialize ADC1 for TIM3 TRGO hardware-triggered acquisition with DMA.
 * @param pclk2_hz APB2 clock frequency in Hz (72 MHz canonical).
 * @return 0 on success, negative error code on calibration timeout.
 */
int adc1_init(uint32_t pclk2_hz);

/**
 * @brief Calculate current ADC clock in Hz based on RCC_CFGR ADCPRE bits.
 */
uint32_t adc_get_clock_hz(uint32_t pclk2_hz);

#endif /* ADC_H */
