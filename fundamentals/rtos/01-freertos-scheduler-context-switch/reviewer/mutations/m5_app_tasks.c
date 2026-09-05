/* Mutation m5: Calls forbidden libc malloc */
#include "app_tasks.h"
#include <stddef.h>
#include <stdlib.h>

static task_telemetry_t *g_pTelemetry = NULL;
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
        if (g_pTelemetry) {
            g_pTelemetry->telemetry_cycles++;
            g_pTelemetry->telemetry_high_water_words = (uint32_t)tel_hwm;
            g_pTelemetry->worker_high_water_words = (uint32_t)wrk_hwm;
            g_pTelemetry->scheduler_coherent = true;
        }
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
        if (g_pTelemetry) {
            g_pTelemetry->worker_cycles++;
        }
        taskEXIT_CRITICAL();
    }
}

bool app_tasks_init(void)
{
    /* MUTATION m5: Calls standard libc malloc */
    g_pTelemetry = (task_telemetry_t *)malloc(sizeof(task_telemetry_t));
    if (!g_pTelemetry) return false;

    BaseType_t status1 = xTaskCreate(vTelemetryTask, "Telemetry", TASK_STACK_SIZE_WORDS, NULL, 2, &xTelemetryTaskHandle);
    if (status1 != pdPASS) return false;

    BaseType_t status2 = xTaskCreate(vWorkerTask, "Worker", TASK_STACK_SIZE_WORDS, NULL, 1, &xWorkerTaskHandle);
    if (status2 != pdPASS) return false;

    return true;
}

void app_tasks_get_telemetry(task_telemetry_t *out_telemetry)
{
    if (!out_telemetry || !g_pTelemetry) return;
    taskENTER_CRITICAL();
    *out_telemetry = *g_pTelemetry;
    taskEXIT_CRITICAL();
}

bool app_tasks_validate_health(void)
{
    task_telemetry_t snap;
    app_tasks_get_telemetry(&snap);
    return (snap.scheduler_coherent && snap.telemetry_high_water_words > 0 && snap.worker_high_water_words > 0);
}
