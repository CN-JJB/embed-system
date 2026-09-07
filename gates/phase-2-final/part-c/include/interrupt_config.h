#ifndef INTERRUPT_CONFIG_H
#define INTERRUPT_CONFIG_H

#include "FreeRTOS.h"
#include "queue.h"

extern QueueHandle_t g_event_queue;

void interrupt_config_init(void);

#endif /* INTERRUPT_CONFIG_H */
