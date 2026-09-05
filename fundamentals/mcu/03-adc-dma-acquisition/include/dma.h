#ifndef DMA_H
#define DMA_H

#include <stdint.h>
#include <stdbool.h>

#define ADC_BUFFER_HALF_SIZE   64
#define ADC_BUFFER_TOTAL_SIZE  (ADC_BUFFER_HALF_SIZE * 2)

/**
 * Contiguous 128-sample static circular acquisition buffer in SRAM.
 * Split into two halves:
 *   - Half 0: g_adc_buffer[0][0..63] (samples 0..63)
 *   - Half 1: g_adc_buffer[1][0..63] (samples 64..127)
 *
 * Explicit Ownership Contract:
 *   - While DMA is filling Half 0, CPU owns and may read Half 1.
 *   - When HT interrupt fires, Half 0 is completed -> CPU owns Half 0, DMA fills Half 1.
 *   - When TC interrupt fires, Half 1 is completed -> CPU owns Half 1, DMA wraps and fills Half 0.
 */
extern volatile uint16_t g_adc_buffer[2][ADC_BUFFER_HALF_SIZE];

extern volatile uint32_t g_dma_ht_count;
extern volatile uint32_t g_dma_tc_count;
extern volatile uint32_t g_dma_te_count;

/**
 * @brief Initialize DMA1 Channel 1 for circular peripheral-to-memory ADC acquisition.
 *
 * Configures:
 *  - RCC AHB clock gate for DMA1.
 *  - CPAR = &ADC1->DR (16-bit peripheral data register).
 *  - CMAR = (uint32_t)g_adc_buffer (persistent static SRAM buffer).
 *  - CNDTR = 128 items.
 *  - CCR: CIRC=1, MINC=1, PINC=0, DIR=0 (P2M), PSIZE=16-bit, MSIZE=16-bit.
 *  - Interrupts: HTIE=1, TCIE=1, TEIE=1.
 *  - NVIC: DMA1_Channel1_IRQn enabled with priority 5.
 */
void dma1_channel1_init(void);

#endif /* DMA_H */
