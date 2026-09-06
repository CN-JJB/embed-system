#ifndef DMA_H
#define DMA_H

#include <stdint.h>
#include <stdbool.h>
#include "FreeRTOS.h"
#include "queue.h"

#define ADC_BUFFER_HALF_SIZE    64U
#define ADC_BUFFER_TOTAL_SIZE   (ADC_BUFFER_HALF_SIZE * 2U)

/**
 * @brief Queue token message emitted by DMA ISR to xAcqQueue upon half/full completion.
 */
typedef struct {
    uint8_t buffer_index;   /* 0 for Half 0 (HT), 1 for Half 1 (TC) */
    uint16_t count;         /* Number of valid samples (64) */
    TickType_t timestamp;   /* Kernel tick timestamp at ISR execution */
    uint32_t sequence;      /* Monotonically increasing acquisition sequence ID */
} AcquisitionMessage_t;

/* Persistent DMA sample pool allocated in static SRAM (2 x 64 uint16_t) */
extern volatile uint16_t g_adc_pool[2][ADC_BUFFER_HALF_SIZE] __attribute__((aligned(4)));

/* Diagnostic transfer and error counters */
extern volatile uint32_t g_dma_ht_count;
extern volatile uint32_t g_dma_tc_count;
extern volatile uint32_t g_dma_te_count;
extern volatile uint32_t g_acq_sequence;
extern volatile uint32_t g_acq_transfers;
extern volatile uint32_t g_acq_drops;

/**
 * @brief Initialize DMA1 Channel 1 for circular double-buffered transfer from ADC1.
 */
void dma1_channel1_init(void);

#endif /* DMA_H */
