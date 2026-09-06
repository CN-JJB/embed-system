#ifndef QUEUE_APP_H
#define QUEUE_APP_H

#include <stdint.h>
#include "FreeRTOS.h"
#include "queue.h"
#include "task.h"

#define QUEUE_APP_LENGTH        10
#define QUEUE_APP_ITEM_SIZE     sizeof(uint32_t)

extern QueueHandle_t g_sample_queue;
extern volatile uint32_t g_consumer_received_count;
extern volatile uint32_t g_consumer_sequence_errors;

/**
 * @brief Initialize queue and consumer task.
 */
void queue_app_init(void);

#endif /* QUEUE_APP_H */
