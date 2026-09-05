#ifndef INVERSION_APP_H
#define INVERSION_APP_H

#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

#define TASK_HIGH_PRIORITY      3
#define TASK_MEDIUM_PRIORITY    2
#define TASK_LOW_PRIORITY       1

extern TaskHandle_t g_task_high_handle;
extern TaskHandle_t g_task_medium_handle;
extern TaskHandle_t g_task_low_handle;

extern SemaphoreHandle_t g_shared_resource;

extern volatile uint32_t g_high_wait_ticks_run_a;
extern volatile uint32_t g_high_wait_ticks_run_b;
extern volatile uint32_t g_low_workload_iterations;

/**
 * @brief Initialize tasks and synchronization primitives for the priority inversion experiment.
 */
void inversion_app_init(void);

/**
 * @brief Convert FreeRTOS high-water mark words to bytes.
 * On Cortex-M3 (StackType_t is 32-bit), 1 word = 4 bytes.
 */
uint32_t inversion_get_watermark_bytes(TaskHandle_t xTask);

/**
 * @brief Execute CPU-runnable bounded workload (strictly no vTaskDelay inside critical section).
 */
void inversion_execute_low_workload(void);

#endif /* INVERSION_APP_H */
