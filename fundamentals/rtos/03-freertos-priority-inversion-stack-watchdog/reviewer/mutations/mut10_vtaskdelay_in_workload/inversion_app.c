#include "inversion_app.h"
#include "iwdg.h"
#include "gpio.h"
#include "core_cm3.h"

TaskHandle_t g_task_high_handle = NULL;
TaskHandle_t g_task_medium_handle = NULL;
TaskHandle_t g_task_low_handle = NULL;

SemaphoreHandle_t g_shared_resource = NULL;

volatile uint32_t g_high_wait_ticks_run_a = 0;
volatile uint32_t g_high_wait_ticks_run_b = 0;
volatile uint32_t g_low_workload_iterations = 0;

static volatile uint8_t s_current_experiment_run = 0; /* 0 = Run A (Sem), 1 = Run B (Mutex) */

void inversion_execute_low_workload(void)
{
    /* Deterministic CPU-runnable critical workload (~5 ms under 72 MHz)
     * Strictly NO vTaskDelay() while holding the measured shared resource!
     */
    volatile uint32_t val = 0x5555AAAAU;
    for (uint32_t i = 0; i < 15000U; i++) {
        val = (val ^ (i + 1U)) * 31U;
        __NOP();
    }
    (void)val;
    vTaskDelay(10); g_low_workload_iterations++;
}

static void prvMediumWorkload(void)
{
    /* Finite CPU-runnable interference workload (~20 ms under 72 MHz) */
    volatile uint32_t val = 0x12345678U;
    for (uint32_t i = 0; i < 60000U; i++) {
        val = (val ^ (i + 1U)) * 17U;
        __NOP();
    }
    (void)val;
}

static void prvTaskHigh(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        /* Wait for deterministic signal from Task_Low */
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);

        TickType_t xStartTick = xTaskGetTickCount();

        /* Attempt to acquire shared resource (blocks because Task_Low holds it) */
        if (xSemaphoreTake(g_shared_resource, portMAX_DELAY) == pdPASS) {
            TickType_t xDuration = xTaskGetTickCount() - xStartTick;

            if (s_current_experiment_run == 0) {
                g_high_wait_ticks_run_a = (uint32_t)xDuration;
            } else {
                g_high_wait_ticks_run_b = (uint32_t)xDuration;
            }

            /* Release resource immediately after acquisition */
            xSemaphoreGive(g_shared_resource);
        }
    }
}

static void prvTaskMedium(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        /* Wait for notification from Task_Low */
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);

        /* Execute medium-priority CPU workload */
        prvMediumWorkload();
    }
}

static void prvTaskLow(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        /* -------------------------------------------------------------
         * RUN A: Binary Semaphore Control (No priority inheritance)
         * ------------------------------------------------------------- */
        s_current_experiment_run = 0;

        /* Create binary semaphore and initialize token */
        if (g_shared_resource != NULL) {
            vSemaphoreDelete(g_shared_resource);
        }
        g_shared_resource = xSemaphoreCreateBinary();
        configASSERT(g_shared_resource != NULL);
        xSemaphoreGive(g_shared_resource);

        /* Step 1: Low acquires lock */
        xSemaphoreTake(g_shared_resource, portMAX_DELAY);

        /* Step 2: Low releases High */
        xTaskNotifyGive(g_task_high_handle);

        /* Step 3: High awakens, blocks on lock. Execution returns to Low.
         * Step 4: Low now releases Medium */
        xTaskNotifyGive(g_task_medium_handle);

        /* Step 5: Low executes CPU critical workload (~5 ms).
         * Under binary semaphore, Medium (priority 2) preempts Low (priority 1).
         * Low cannot finish until Medium finishes (~20 ms).
         */
        inversion_execute_low_workload();

        /* Step 6: Low releases lock; High unblocks */
        xSemaphoreGive(g_shared_resource);

        /* Yield briefly to allow High and Medium to settle */
        vTaskDelay(pdMS_TO_TICKS(50));

        /* -------------------------------------------------------------
         * RUN B: Mutex (Priority inheritance active)
         * ------------------------------------------------------------- */
        s_current_experiment_run = 1;

        /* Create mutex with priority inheritance */
        vSemaphoreDelete(g_shared_resource);
        g_shared_resource = xSemaphoreCreateMutex();
        configASSERT(g_shared_resource != NULL);

        /* Step 1: Low acquires mutex */
        xSemaphoreTake(g_shared_resource, portMAX_DELAY);

        /* Step 2: Low releases High */
        xTaskNotifyGive(g_task_high_handle);

        /* Step 3: High blocks on mutex. Low inherits Priority 3!
         * Step 4: Low releases Medium */
        xTaskNotifyGive(g_task_medium_handle);

        /* Step 5: Low executes identical CPU critical workload (~5 ms).
         * Because Low inherited priority 3, Medium (priority 2) cannot preempt Low!
         * Low finishes work promptly.
         */
        inversion_execute_low_workload();

        /* Step 6: Low releases mutex, disinherits back to priority 1; High runs */
        xSemaphoreGive(g_shared_resource);

        /* Inspect stack watermark */
        volatile uint32_t wm_bytes = inversion_get_watermark_bytes(g_task_low_handle);
        (void)wm_bytes;

        /* Refresh watchdog after healthy cycle completion */
        iwdg_refresh();

        /* Pause between experiment cycles */
        vTaskDelay(pdMS_TO_TICKS(100));
        gpio_toggle_led();
    }
}

uint32_t inversion_get_watermark_bytes(TaskHandle_t xTask)
{
    /* FreeRTOS reports high-water mark in StackType_t words.
     * On Cortex-M3, sizeof(StackType_t) is 4 bytes.
     */
    UBaseType_t words = uxTaskGetStackHighWaterMark(xTask);
    return (uint32_t)(words * sizeof(StackType_t));
}

void inversion_app_init(void)
{
    /* Create Task_Low (Priority 1) */
    BaseType_t xRet = xTaskCreate(
        prvTaskLow,
        "Low",
        256,
        NULL,
        TASK_LOW_PRIORITY,
        &g_task_low_handle
    );
    configASSERT(xRet == pdPASS);

    /* Create Task_Medium (Priority 2) */
    xRet = xTaskCreate(
        prvTaskMedium,
        "Medium",
        256,
        NULL,
        TASK_MEDIUM_PRIORITY,
        &g_task_medium_handle
    );
    configASSERT(xRet == pdPASS);

    /* Create Task_High (Priority 3) */
    xRet = xTaskCreate(
        prvTaskHigh,
        "High",
        256,
        NULL,
        TASK_HIGH_PRIORITY,
        &g_task_high_handle
    );
    configASSERT(xRet == pdPASS);
}
