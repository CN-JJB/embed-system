/**
 * =============================================================================
 * Challenge Starter: Real-Time Dual-Task Scheduler & Telemetry Monitor
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M04 FreeRTOS Scheduler, Task Lifecycle, and Context Switch
 * =============================================================================
 * Instructions:
 * Complete the implementation of app_tasks_init, task loops, and thread-safe
 * telemetry retrieval to satisfy real-time determinism and memory safety bounds.
 * =============================================================================
 */

#include "app_tasks.h"
#include <stddef.h>

static task_telemetry_t g_telemetry = { 0 };
static TaskHandle_t xTelemetryTaskHandle = NULL;
static TaskHandle_t xWorkerTaskHandle = NULL;

static void vTelemetryTask(void *pvParameters)
{
    (void)pvParameters;
    /* TODO: Implement periodic telemetry task using vTaskDelayUntil with TELEMETRY_PERIOD_MS.
     * Update telemetry_cycles and telemetry_high_water_words safely.
     */
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

static void vWorkerTask(void *pvParameters)
{
    (void)pvParameters;
    /* TODO: Implement periodic worker task using vTaskDelayUntil with WORKER_PERIOD_MS.
     * Update worker_cycles and worker_high_water_words safely.
     */
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

bool app_tasks_init(void)
{
    /* TODO:
     * 1. Create Telemetry task with priority 2 and TASK_STACK_SIZE_WORDS stack.
     * 2. Create Worker task with priority 1 and TASK_STACK_SIZE_WORDS stack.
     * 3. Validate creation return codes. Return false if any allocation fails.
     */
    return false;
}

void app_tasks_get_telemetry(task_telemetry_t *out_telemetry)
{
    if (!out_telemetry) return;

    /* TODO: Read g_telemetry in a thread-safe manner (e.g. taskENTER_CRITICAL / taskEXIT_CRITICAL) */
    *out_telemetry = g_telemetry;
}

bool app_tasks_validate_health(void)
{
    /* TODO: Verify positive stack margins and non-zero cycle progress */
    return false;
}
