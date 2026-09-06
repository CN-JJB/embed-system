#include "clock.h"
#include "gpio.h"
#include "iwdg.h"
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "core_cm3.h"

static TaskHandle_t s_sensor_task_handle = NULL;
static TaskHandle_t s_filter_task_handle = NULL;
static TaskHandle_t s_telemetry_task_handle = NULL;

static SemaphoreHandle_t s_shared_buffer_sem = NULL;

volatile uint32_t g_sensor_wait_ticks = 0;
volatile uint32_t g_reported_watermark_bytes = 0;

static void prvFilterWorkload(void)
{
    /* Simulate intensive filter computation (DESIGN TARGET / UNVERIFIED: ~20 ms) */
    volatile uint32_t acc = 0x12345678U;
    for (uint32_t i = 0; i < 60000U; i++) {
        acc = (acc ^ (i + 1U)) * 17U;
        __NOP();
    }
    (void)acc;
}

static void prvSensorTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        /* Wait for trigger from telemetry */
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);

        TickType_t start_tick = xTaskGetTickCount();

        /* Attempt to acquire shared buffer */
        if (xSemaphoreTake(s_shared_buffer_sem, portMAX_DELAY) == pdPASS) {
            g_sensor_wait_ticks = (uint32_t)(xTaskGetTickCount() - start_tick);

            /* Release immediately */
            xSemaphoreGive(s_shared_buffer_sem);
        }
    }
}

static void prvFilterTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        prvFilterWorkload();
    }
}

static void prvTelemetryTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        /* Step 1: Telemetry acquires shared buffer */
        xSemaphoreTake(s_shared_buffer_sem, portMAX_DELAY);

        /* Step 2: Signal high-priority sensor task */
        xTaskNotifyGive(s_sensor_task_handle);

        /* Step 3: Signal medium-priority filter task */
        xTaskNotifyGive(s_filter_task_handle);

        /* Step 4: Execute telemetry buffer formatting (DESIGN TARGET / UNVERIFIED: ~5 ms) */
        volatile uint32_t acc = 0x5555AAAAU;
        for (uint32_t i = 0; i < 15000U; i++) {
            acc = (acc ^ (i + 1U)) * 31U;
            __NOP();
        }
        (void)acc;

        /* Step 5: Release buffer */
        xSemaphoreGive(s_shared_buffer_sem);

        /* Sample stack high-water mark for telemetry health payload */
        UBaseType_t wm_words = uxTaskGetStackHighWaterMark(s_telemetry_task_handle);
        g_reported_watermark_bytes = (uint32_t)wm_words;

        /* Refresh watchdog */
        iwdg_refresh();

        vTaskDelay(pdMS_TO_TICKS(100));
        gpio_toggle_led();
    }
}

void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName)
{
    (void)xTask;
    (void)pcTaskName;
    __disable_irq();
    for (;;) {
        __NOP();
    }
}

int main(void)
{
    clock_init(CLOCK_PROFILE_72MHZ_HSE);
    gpio_init();
    NVIC_SetPriorityGrouping(0);

    /* 1. Check and clear watchdog reset flag */
    iwdg_check_and_clear_reset_cause();

    /* 2. Configure watchdog */
    iwdg_init(4, 1250);

    /* Allocate synchronization primitive for shared buffer */
    s_shared_buffer_sem = xSemaphoreCreateBinary();
    xSemaphoreGive(s_shared_buffer_sem);

    /* Create tasks */
    xTaskCreate(prvTelemetryTask, "Telem", 256, NULL, 1, &s_telemetry_task_handle);
    xTaskCreate(prvFilterTask, "Filter", 256, NULL, 2, &s_filter_task_handle);
    xTaskCreate(prvSensorTask, "Sensor", 256, NULL, 3, &s_sensor_task_handle);

    vTaskStartScheduler();

    while (1) {
        __NOP();
    }
    return 0;
}
