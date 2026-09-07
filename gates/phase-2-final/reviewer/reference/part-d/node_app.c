#include "node_app.h"
#include "stm32f103xb.h"
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

SemaphoreHandle_t xSensorBusLock = NULL;
SemaphoreHandle_t xLogBufferLock = NULL;

volatile uint32_t g_telemetry_cycles = 0;
volatile uint32_t g_storage_cycles = 0;

__attribute__((noinline))
void iwdg_init(void)
{
    /* Enable write access to IWDG_PR and IWDG_RLR */
    IWDG->KR = 0x5555;
    /* Prescaler /64 -> nominal 625 Hz from LSI 40 kHz */
    IWDG->PR = 0x04;
    /* Reload value 312 -> downcounter counts 313 cycles -> nominal 500.8 ms timeout */
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
        /* Sample telemetry under shared sensor bus protection */
        if (xSemaphoreTake(xSensorBusLock, portMAX_DELAY) == pdTRUE) {
            g_telemetry_cycles++;
            xSemaphoreGive(xSensorBusLock);

            /* Refresh hardware watchdog after successful acquisition */
            iwdg_refresh();
        }

        vTaskDelayUntil(&xLastWakeTime, pdMS_TO_TICKS(50));
    }
}

static void task_storage(void *pvParameters)
{
    (void)pvParameters;

    /* Initial phase offset to decouple periodic task boundaries */
    vTaskDelay(pdMS_TO_TICKS(20));

    while (1) {
        /* Storage logging cycle */
        if (xSemaphoreTake(xSensorBusLock, portMAX_DELAY) == pdTRUE) {
            g_storage_cycles++;
            /*
             * Reference fix: properly release the acquired xSensorBusLock mutex,
             * preventing resource starvation and enabling periodic watchdog refresh.
             */
            xSemaphoreGive(xSensorBusLock);
        }

        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

void node_app_init(void)
{
    /* Initialize mutual exclusion locks for shared resources */
    xSensorBusLock = xSemaphoreCreateMutex();
    xLogBufferLock = xSemaphoreCreateMutex();

    /* Initialize hardware independent watchdog */
    iwdg_init();

    /* Create real-time tasks across priority levels */
    xTaskCreate(task_telemetry, "Task_Telemetry", configMINIMAL_STACK_SIZE + 64, NULL, 2, NULL);
    xTaskCreate(task_storage,   "Task_Storage",   configMINIMAL_STACK_SIZE + 64, NULL, 1, NULL);
}
