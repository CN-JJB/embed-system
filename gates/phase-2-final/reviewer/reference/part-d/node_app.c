#include "node_app.h"
#include "stm32f103xb.h"
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

SemaphoreHandle_t xSensorBusLock = NULL;
SemaphoreHandle_t xTelemetryBufferLock = NULL;

volatile uint32_t g_telemetry_cycles = 0;
volatile uint32_t g_storage_cycles = 0;

__attribute__((noinline))
void iwdg_init(void)
{
    /* Enable write access to IWDG_PR and IWDG_RLR */
    IWDG->KR = 0x5555;
    /* Prescaler /64 -> nominal 625 Hz from LSI 40 kHz */
    IWDG->PR = 0x04;
    /* Reload value 312 -> nominal 500 ms timeout */
    IWDG->RLR = 312;
    /* Reload counter */
    IWDG->KR = 0xAAAA;
    /* Start watchdog */
    IWDG->KR = 0xCCCC;
}

void iwdg_refresh(void)
{
    IWDG->KR = 0xAAAA;
}

static void task_telemetry(void *pvParameters)
{
    (void)pvParameters;
    TickType_t xLastWakeTime = xTaskGetTickCount();

    while (1) {
        vTaskDelayUntil(&xLastWakeTime, pdMS_TO_TICKS(50));

        /* Telemetry task acquires Sensor Bus Lock then Telemetry Buffer Lock */
        if (xSemaphoreTake(xSensorBusLock, portMAX_DELAY) == pdTRUE) {
            if (xSemaphoreTake(xTelemetryBufferLock, portMAX_DELAY) == pdTRUE) {
                g_telemetry_cycles++;
                xSemaphoreGive(xTelemetryBufferLock);
            }
            xSemaphoreGive(xSensorBusLock);
        }

        /* Refresh hardware watchdog */
        iwdg_refresh();
    }
}

static void task_storage(void *pvParameters)
{
    (void)pvParameters;

    while (1) {
        vTaskDelay(pdMS_TO_TICKS(100));

        /*
         * Reference Fix: Enforce canonical lock acquisition hierarchy.
         * Acquires xSensorBusLock before xTelemetryBufferLock, identical
         * to task_telemetry, eliminating circular wait deadlock.
         */
        if (xSemaphoreTake(xSensorBusLock, portMAX_DELAY) == pdTRUE) {
            if (xSemaphoreTake(xTelemetryBufferLock, portMAX_DELAY) == pdTRUE) {
                g_storage_cycles++;
                xSemaphoreGive(xTelemetryBufferLock);
            }
            xSemaphoreGive(xSensorBusLock);
        }
    }
}

void node_app_init(void)
{
    /* Initialize mutual exclusion locks for shared resources */
    xSensorBusLock = xSemaphoreCreateMutex();
    xTelemetryBufferLock = xSemaphoreCreateMutex();

    /* Initialize hardware independent watchdog */
    iwdg_init();

    /* Create real-time tasks across priority levels */
    xTaskCreate(task_telemetry, "Task_Telemetry", configMINIMAL_STACK_SIZE + 64, NULL, 2, NULL);
    xTaskCreate(task_storage,   "Task_Storage",   configMINIMAL_STACK_SIZE + 64, NULL, 1, NULL);
}
