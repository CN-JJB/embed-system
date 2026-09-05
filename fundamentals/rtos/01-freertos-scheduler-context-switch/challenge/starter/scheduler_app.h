#ifndef SCHEDULER_APP_H
#define SCHEDULER_APP_H

#include <stdint.h>
#include <stdbool.h>
#include "clock.h"
#include "FreeRTOS.h"
#include "task.h"

#define TASK_A_PRIORITY        (tskIDLE_PRIORITY + 2)
#define TASK_B_PRIORITY        (tskIDLE_PRIORITY + 1)
#define TASK_STACK_SIZE_WORDS  128U

/**
 * @brief Initialize clock tree, GPIO markers, create dual tasks, and start scheduler.
 *
 * Integration Contract:
 * 1. Clock initialization:
 *    - Attempt primary profile (CLOCK_PROFILE_72MHZ_HSE).
 *    - If HSE fails, fall back to CLOCK_PROFILE_64MHZ_HSI.
 *    - Return negative error if both fail.
 * 2. Task creation:
 *    - Task_A: Priority 2, stack TASK_STACK_SIZE_WORDS (128 words).
 *      Toggles PA1 and yields CPU via periodic vTaskDelay(pdMS_TO_TICKS(5)).
 *    - Task_B: Priority 1, stack TASK_STACK_SIZE_WORDS (128 words).
 *      Toggles PA2 and executes CPU-runnable workload while Task_A is blocked.
 *    - Return codes from xTaskCreate must be validated.
 * 3. Scheduler launch:
 *    - Call vTaskStartScheduler().
 *
 * @param profile Requested primary clock profile.
 * @return Does not return after successful scheduler start; returns a negative error code if clock/task/scheduler startup fails.
 */
int scheduler_app_init_and_start(clock_profile_t profile);

#endif /* SCHEDULER_APP_H */
