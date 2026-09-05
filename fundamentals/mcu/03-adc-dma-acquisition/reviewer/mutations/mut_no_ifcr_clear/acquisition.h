#ifndef ACQUISITION_H
#define ACQUISITION_H

#include <stdint.h>
#include <stdbool.h>

#define ACQ_HALF_BUFFER_SIZE   64
#define ACQ_TOTAL_BUFFER_SIZE  128

extern volatile uint16_t g_acq_buffer[2][ACQ_HALF_BUFFER_SIZE];
extern volatile uint32_t g_acq_ht_events;
extern volatile uint32_t g_acq_tc_events;

/**
 * @brief Initialize autonomous ADC + DMA acquisition pipeline.
 *
 * Configures TIM3 TRGO @ 10 kHz, ADC1 with ADCPRE=/6, PA0 analog input,
 * 55.5 cycles sample time, calibration, external trigger, and DMA1 Channel 1.
 *
 * @param sysclk_hz Active system core clock (72000000 or 64000000).
 * @return 0 on success, negative on calibration timeout.
 */
int acquisition_pipeline_init(uint32_t sysclk_hz);

void DMA1_Channel1_IRQHandler(void);

#endif /* ACQUISITION_H */
