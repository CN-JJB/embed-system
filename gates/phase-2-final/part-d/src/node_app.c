#include "node_app.h"
#include "stm32f103xb.h"
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

SemaphoreHandle_t xSensorBusLock = NULL;

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
        vTaskDelayUntil(&xLastWakeTime, pdMS_TO_TICKS(50));

        /* Refresh hardware watchdog */
        iwdg_refresh();

        /* Sample sensor telemetry under bus protection */
        if (xSemaphoreTake(xSensorBusLock, portMAX_DELAY) == pdTRUE) {
            g_telemetry_cycles++;
            xSemaphoreGive(xSensorBusLock);
        }
    }
}

static void task_storage(void *pvParameters)
{
    (void)pvParameters;

    while (1) {
        vTaskDelay(pdMS_TO_TICKS(100));

        /* Storage task logging cycle */
        if (xSemaphoreTake(xSensorBusLock, portMAX_DELAY) == pdTRUE) {
            g_storage_cycles++;
        }
    }
}

void node_app_init(void)
{
    /* Initialize mutual exclusion lock for shared sensor bus */
    xSensorBusLock = xSemaphoreCreateMutex();

    /* Initialize hardware independent watchdog */
    iwdg_init();

    /* Create real-time tasks across priority levels */
    xTaskCreate(task_telemetry, "Task_Telemetry", configMINIMAL_STACK_SIZE + 64, NULL, 2, NULL);
    xTaskCreate(task_storage,   "Task_Storage",   configMINIMAL_STACK_SIZE + 64, NULL, 1, NULL);
}
