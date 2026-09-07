#include "node_app.h"
#include "stm32f103xb.h"
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

SemaphoreHandle_t xSharedResourceLock = NULL;

volatile uint32_t g_telemetry_cycles = 0;
volatile uint32_t g_compute_cycles = 0;
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

        /* High-priority telemetry task acquires shared resource lock */
        if (xSemaphoreTake(xSharedResourceLock, portMAX_DELAY) == pdTRUE) {
            g_telemetry_cycles++;
            xSemaphoreGive(xSharedResourceLock);
        }
    }
}

static void task_compute(void *pvParameters)
{
    (void)pvParameters;

    while (1) {
        vTaskDelay(pdMS_TO_TICKS(100));

        /* Medium priority CPU-bound workload */
        for (volatile uint32_t i = 0; i < 50000; i++) {
            g_compute_cycles++;
        }
    }
}

static void task_storage(void *pvParameters)
{
    (void)pvParameters;

    while (1) {
        /* Low-priority storage logging task acquires shared resource lock */
        if (xSemaphoreTake(xSharedResourceLock, portMAX_DELAY) == pdTRUE) {
            /* Simulate data write and stack audit */
            for (volatile uint32_t i = 0; i < 5000; i++) {
                g_storage_cycles++;
            }
            xSemaphoreGive(xSharedResourceLock);
        }

        /* Refresh hardware watchdog and delay */
        iwdg_refresh();
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

void node_app_init(void)
{
    /*
     * Initialize shared resource mutual exclusion primitive.
     */
    xSharedResourceLock = xSemaphoreCreateBinary();
    if (xSharedResourceLock != NULL) {
        xSemaphoreGive(xSharedResourceLock);
    }

    /* Initialize hardware independent watchdog */
    iwdg_init();

    /* Create tasks across 3 distinct priority levels */
    xTaskCreate(task_telemetry, "Task_Telemetry", configMINIMAL_STACK_SIZE + 64, NULL, 3, NULL);
    xTaskCreate(task_compute,   "Task_Compute",   configMINIMAL_STACK_SIZE + 64, NULL, 2, NULL);
    xTaskCreate(task_storage,   "Task_Storage",   configMINIMAL_STACK_SIZE + 64, NULL, 1, NULL);
}
