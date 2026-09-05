#ifndef ACQUISITION_H
#define ACQUISITION_H

#include <stdint.h>
#include <stdbool.h>

#define ACQ_HALF_BUFFER_SIZE   64
#define ACQ_TOTAL_BUFFER_SIZE  128

extern volatile uint16_t g_acq_buffer[2][ACQ_HALF_BUFFER_SIZE];
extern volatile uint32_t g_acq_ht_events;
extern volatile uint32_t g_acq_tc_events;
extern volatile uint32_t g_acq_te_events;

/**
 * @brief Initialize autonomous ADC + DMA acquisition pipeline.
 *
 * @param timclk_hz Active TIM3 input clock frequency in Hz.
 *                  In STM32F1, f_TIM3 = (APB1_prescaler == 1) ? f_PCLK1 : (2 * f_PCLK1).
 *                  For 72 MHz profile (PCLK1=36 MHz), f_TIM3 = 72000000 Hz.
 *                  For 64 MHz fallback (PCLK1=32 MHz), f_TIM3 = 64000000 Hz.
 * @return 0 on success, negative on calibration timeout or error.
 */
int acquisition_pipeline_init(uint32_t timclk_hz);

void DMA1_Channel1_IRQHandler(void);

#endif /* ACQUISITION_H */
