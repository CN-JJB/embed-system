/* Mutation m3: Undersized stack depth (violates TASK_STACK_SIZE_WORDS budget) */
#include "app_tasks.h"
#include <stddef.h>

static task_telemetry_t g_telemetry = { 0 };
static TaskHandle_t xTelemetryTaskHandle = NULL;
static TaskHandle_t xWorkerTaskHandle = NULL;

static void vTelemetryTask(void *pvParameters)
{
    (void)pvParameters;
    TickType_t xLastWakeTime = xTaskGetTickCount();
    for (;;) {
        vTaskDelayUntil(&xLastWakeTime, pdMS_TO_TICKS(TELEMETRY_PERIOD_MS));
        taskENTER_CRITICAL();
        g_telemetry.telemetry_cycles++;
        taskEXIT_CRITICAL();
    }
}

static void vWorkerTask(void *pvParameters)
{
    (void)pvParameters;
    TickType_t xLastWakeTime = xTaskGetTickCount();
    for (;;) {
        vTaskDelayUntil(&xLastWakeTime, pdMS_TO_TICKS(WORKER_PERIOD_MS));
        taskENTER_CRITICAL();
        g_telemetry.worker_cycles++;
        taskEXIT_CRITICAL();
    }
}

bool app_tasks_init(void)
{
    /* MUTATION m3: Stacks configured to 16 words instead of TASK_STACK_SIZE_WORDS (128) */
    BaseType_t status1 = xTaskCreate(vTelemetryTask, "Telemetry", 16, NULL, 2, &xTelemetryTaskHandle);
    if (status1 != pdPASS) return false;

    BaseType_t status2 = xTaskCreate(vWorkerTask, "Worker", 16, NULL, 1, &xWorkerTaskHandle);
    if (status2 != pdPASS) return false;

    return true;
}

void app_tasks_get_telemetry(task_telemetry_t *out_telemetry)
{
    if (!out_telemetry) return;
    taskENTER_CRITICAL();
    *out_telemetry = g_telemetry;
    taskEXIT_CRITICAL();
}

bool app_tasks_validate_health(void)
{
    task_telemetry_t snap;
    app_tasks_get_telemetry(&snap);
    return (snap.scheduler_coherent);
}
