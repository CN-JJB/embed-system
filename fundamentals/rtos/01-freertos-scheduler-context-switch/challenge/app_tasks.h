#ifndef APP_TASKS_H
#define APP_TASKS_H

#include <stdint.h>
#include <stdbool.h>
#include "FreeRTOS.h"
#include "task.h"

#define TELEMETRY_PERIOD_MS    50U
#define WORKER_PERIOD_MS       100U
#define TASK_STACK_SIZE_WORDS  128U

typedef struct {
    uint32_t telemetry_cycles;
    uint32_t worker_cycles;
    uint32_t telemetry_high_water_words;
    uint32_t worker_high_water_words;
    bool scheduler_coherent;
} task_telemetry_t;

/**
 * @brief Initialize real-time dual-task monitor.
 *
 * Creates:
 *  - "Telemetry": Priority 2, executes every 50 ms via vTaskDelayUntil, tracks high water mark.
 *  - "Worker": Priority 1, executes every 100 ms via vTaskDelayUntil, performs workload.
 *
 * Stacks must be sized strictly to TASK_STACK_SIZE_WORDS.
 *
 * @return true if both tasks created successfully, false otherwise.
 */
bool app_tasks_init(void);

/**
 * @brief Retrieve a thread-safe snapshot of task telemetry.
 *
 * @param out_telemetry Destination buffer.
 */
void app_tasks_get_telemetry(task_telemetry_t *out_telemetry);

/**
 * @brief Validate task stack and scheduler health invariants.
 *
 * @return true if both tasks have positive stack margins and positive cycle counts.
 */
bool app_tasks_validate_health(void);

#endif /* APP_TASKS_H */
