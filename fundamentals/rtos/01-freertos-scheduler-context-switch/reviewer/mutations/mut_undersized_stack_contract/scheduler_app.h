#ifndef SCHEDULER_APP_H
#define SCHEDULER_APP_H

#include <stdint.h>
#include <stdbool.h>
#include "clock.h"
#include "FreeRTOS.h"
#include "task.h"

#define TASK_A_PRIORITY        (tskIDLE_PRIORITY + 2)
#define TASK_B_PRIORITY        (tskIDLE_PRIORITY + 1)
/* Defect: undersized stack below required 128 words contract */
#define TASK_STACK_SIZE_WORDS  64U

/**
 * @brief Initialize clock tree, GPIO markers, create dual tasks, and start scheduler.
 */
int scheduler_app_init_and_start(clock_profile_t profile);

#endif /* SCHEDULER_APP_H */
