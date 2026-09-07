#ifndef NODE_APP_H
#define NODE_APP_H

#include <stdint.h>
#include "FreeRTOS.h"
#include "semphr.h"

extern SemaphoreHandle_t xSharedResourceLock;

void node_app_init(void);
__attribute__((noinline)) void iwdg_init(void);
void iwdg_refresh(void);

#endif /* NODE_APP_H */
