/* Mutation m2: Inverted task priorities (Worker higher than Telemetry) */
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
    /* MUTATION m2: Priority inverted: Telemetry gets 1, Worker gets 2 */
    BaseType_t status1 = xTaskCreate(vTelemetryTask, "Telemetry", TASK_STACK_SIZE_WORDS, NULL, 1, &xTelemetryTaskHandle);
    if (status1 != pdPASS) return false;

    BaseType_t status2 = xTaskCreate(vWorkerTask, "Worker", TASK_STACK_SIZE_WORDS, NULL, 2, &xWorkerTaskHandle);
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
    return (snap.scheduler_coherent && snap.telemetry_high_water_words > 0 && snap.worker_high_water_words > 0);
}
