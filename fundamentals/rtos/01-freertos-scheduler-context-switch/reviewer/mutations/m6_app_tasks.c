/* Mutation m6: Unchecked task creation return codes (blindly returns true) */
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
        UBaseType_t tel_hwm = uxTaskGetStackHighWaterMark(xTelemetryTaskHandle);
        UBaseType_t wrk_hwm = xWorkerTaskHandle ? uxTaskGetStackHighWaterMark(xWorkerTaskHandle) : 0;
        taskENTER_CRITICAL();
        g_telemetry.telemetry_cycles++;
        g_telemetry.telemetry_high_water_words = (uint32_t)tel_hwm;
        g_telemetry.worker_high_water_words = (uint32_t)wrk_hwm;
        g_telemetry.scheduler_coherent = true;
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
    /* MUTATION m6: Return codes completely ignored */
    xTaskCreate(vTelemetryTask, "Telemetry", TASK_STACK_SIZE_WORDS, NULL, 2, &xTelemetryTaskHandle);
    xTaskCreate(vWorkerTask, "Worker", TASK_STACK_SIZE_WORDS, NULL, 1, &xWorkerTaskHandle);
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
    return (snap.scheduler_coherent && snap.telemetry_high_water_words > 0 && snap.worker_high_water_words > 0);
}
