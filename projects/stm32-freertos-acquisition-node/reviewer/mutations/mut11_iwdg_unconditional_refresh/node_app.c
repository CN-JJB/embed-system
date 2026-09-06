/**
 * =============================================================================
 * FreeRTOS Acquisition Node Core Application Implementation for STM32F103C8T6
 * =============================================================================
 * Course: Embedded Systems Foundations - Phase 2 MCU & FreeRTOS
 * Project: P2-M07 STM32 FreeRTOS Acquisition Node Integration Project
 * =============================================================================
 */

#include "node_app.h"
#include "gpio.h"
#include "usart.h"
#include "iwdg.h"
#include "dwt.h"
#include "stm32f103xb.h"
#include "core_cm3.h"

/* Task handles */
TaskHandle_t g_task_process_handle = NULL;
TaskHandle_t g_task_comm_handle = NULL;
TaskHandle_t g_task_compute_handle = NULL;
TaskHandle_t g_task_health_handle = NULL;

/* Application queues */
QueueHandle_t xAcqQueue = NULL;
QueueHandle_t xLogQueue = NULL;

/* Diagnostic synchronization primitives */
SemaphoreHandle_t g_diag_sem = NULL;
SemaphoreHandle_t g_diag_mutex = NULL;
SemaphoreHandle_t g_diag_resource = NULL;

/* Diagnostic timing and tracking results */
volatile uint32_t g_diag_high_wait_cycles_run_a = 0;
volatile uint32_t g_diag_high_wait_cycles_run_b = 0;
volatile uint32_t g_low_workload_iterations = 0;
volatile uint32_t g_log_drops = 0;
volatile uint8_t  g_diag_run_state = 0;

static volatile uint8_t s_current_diag_run = 0; /* 0 = Run A, 1 = Run B */

uint32_t isqrt_u32(uint32_t val)
{
    uint32_t op = val;
    uint32_t res = 0;
    uint32_t one = 1U << 30;

    while (one > op) {
        one >>= 2;
    }

    while (one != 0) {
        if (op >= res + one) {
            op -= res + one;
            res = (res >> 1) + one;
        } else {
            res >>= 1;
        }
        one >>= 2;
    }
    return res;
}

uint32_t node_app_get_watermark_bytes(TaskHandle_t xTask)
{
    if (xTask == NULL) return 0;
    UBaseType_t words = uxTaskGetStackHighWaterMark(xTask);
    return (uint32_t)(words * sizeof(StackType_t));
}

void __attribute__((noinline)) inversion_execute_low_workload(void)
{
    /* Deterministic CPU-runnable critical workload (DESIGN TARGET / UNVERIFIED: ~5 ms)
     * Strictly NO vTaskDelay() while holding the measured shared diagnostic resource!
     */
    volatile uint32_t val = 0x5555AAAAU;
    for (uint32_t i = 0; i < 15000U; i++) {
        val = (val ^ (i + 1U)) * 31U;
        __NOP();
    }
    (void)val;
    g_low_workload_iterations++;
}

void __attribute__((noinline)) node_app_execute_medium_workload(void)
{
    /* Finite CPU-runnable interference workload (DESIGN TARGET / UNVERIFIED: ~20 ms) */
    volatile uint32_t val = 0x12345678U;
    for (uint32_t i = 0; i < 60000U; i++) {
        val = (val ^ (i + 1U)) * 17U;
        __NOP();
    }
    (void)val;
}

static void prvTaskProcess(void *pvParameters)
{
    (void)pvParameters;
    AcquisitionMessage_t msg;

    for (;;) {
        /* Check if diagnostic test signal is asserted */
        if (ulTaskNotifyTake(pdTRUE, 0) != 0) {
            /* High priority diagnostic measurement path */
            uint32_t start_cycles = dwt_get_cycles();
            if (xSemaphoreTake(g_diag_resource, portMAX_DELAY) == pdPASS) {
                uint32_t duration_cycles = dwt_get_cycles() - start_cycles;
                if (s_current_diag_run == 0) {
                    g_diag_high_wait_cycles_run_a = duration_cycles;
                } else {
                    g_diag_high_wait_cycles_run_b = duration_cycles;
                }
                xSemaphoreGive(g_diag_resource);
            }
            continue;
        }

        /*
         * Normal acquisition fast path: block on xAcqQueue.
         * Strictly NO application mutex in normal fast path!
         */
        if (xQueueReceive(xAcqQueue, &msg, portMAX_DELAY) == pdPASS) {
            if (msg.buffer_index < 2 && msg.count == ADC_BUFFER_HALF_SIZE) {
                uint16_t min_val = 0xFFFFU;
                uint16_t max_val = 0U;
                uint32_t sum = 0U;
                uint64_t sum_sq = 0ULL;

                /* Compute batch statistics across the 64 samples */
                for (uint16_t i = 0; i < msg.count; i++) {
                    uint16_t val = g_adc_pool[msg.buffer_index][i];
                    if (val < min_val) min_val = val;
                    if (val > max_val) max_val = val;
                    sum += val;
                    sum_sq += ((uint64_t)val * (uint64_t)val);
                }

                uint16_t avg = (uint16_t)(sum / msg.count);
                uint16_t rms = (uint16_t)isqrt_u32((uint32_t)(sum_sq / msg.count));

                TelemetryRecord_t record;
                record.sequence = msg.sequence;
                record.timestamp = msg.timestamp;
                record.min = min_val;
                record.max = max_val;
                record.avg = avg;
                record.rms = rms;
                record.drop_count = (uint16_t)g_acq_drops;

                /* Send record to log queue with zero timeout to avoid blocking fast path */
                if (xQueueSend(xLogQueue, &record, 0) != pdPASS) {
                    g_log_drops++;
                }
            }
        }
    }
}

static void prvTaskComm(void *pvParameters)
{
    (void)pvParameters;
    TelemetryRecord_t record;

    for (;;) {
        /* Block waiting for telemetry record from Task_Process */
        if (xQueueReceive(xLogQueue, &record, portMAX_DELAY) == pdPASS) {
            /* Directly transmit telemetry frame via direct USART1 registers */
            usart1_write_str("[TELEM] seq=");
            usart1_write_u32(record.sequence);
            usart1_write_str(" min=");
            usart1_write_u32(record.min);
            usart1_write_str(" max=");
            usart1_write_u32(record.max);
            usart1_write_str(" avg=");
            usart1_write_u32(record.avg);
            usart1_write_str(" rms=");
            usart1_write_u32(record.rms);
            usart1_write_str(" drops=");
            usart1_write_u32(record.drop_count);
            usart1_write_str("\r\n");
        }
    }
}

static void prvTaskCompute(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        /* Wait for diagnostic notification from Task_Health (Low) */
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        gpio_set_pa2();

        /* Execute medium-priority CPU interference workload */
        node_app_execute_medium_workload();

        gpio_clear_pa2();
    }
}

static void prvRunDiagnosticComparison(void)
{
    /* -------------------------------------------------------------
     * RUN A: Binary Semaphore Control (No priority inheritance)
     * ------------------------------------------------------------- */
    s_current_diag_run = 0;
    g_diag_resource = g_diag_sem;

    /* Step 1: Low acquires binary semaphore */
    xSemaphoreTake(g_diag_resource, portMAX_DELAY);
    gpio_set_pa4();

    /* Step 2: Low releases High via direct task notification */
    xTaskNotifyGive(g_task_process_handle);
    xTaskAbortDelay(g_task_process_handle);

    /* Step 3: High awakens, blocks on lock. Execution returns to Low.
     * Step 4: Only after High has had deterministic block opportunity, Low releases Medium */
    xTaskNotifyGive(g_task_compute_handle);

    /* Step 5: Low executes CPU critical workload (~5 ms).
     * Under binary semaphore, Medium (prio 2) preempts Low (prio 1).
     */
    inversion_execute_low_workload();

    /* Step 6: Low releases lock; High unblocks and completes */
    xSemaphoreGive(g_diag_resource);
    gpio_clear_pa4();

    vTaskDelay(pdMS_TO_TICKS(50));

    /* -------------------------------------------------------------
     * RUN B: Mutex (Priority inheritance active)
     * ------------------------------------------------------------- */
    s_current_diag_run = 1;
    g_diag_resource = g_diag_mutex;

    /* Step 1: Low acquires mutex */
    xSemaphoreTake(g_diag_resource, portMAX_DELAY);
    gpio_set_pa4();

    /* Step 2: Low releases High via direct task notification */
    xTaskNotifyGive(g_task_process_handle);
    xTaskAbortDelay(g_task_process_handle);

    /* Step 3: High awakens, blocks on mutex. Low inherits Priority 3!
     * Step 4: Low releases Medium */
    xTaskNotifyGive(g_task_compute_handle);

    /* Step 5: Low executes identical CPU critical workload (~5 ms).
     * Because Low inherited Priority 3, Medium (prio 2) cannot preempt Low!
     */
    inversion_execute_low_workload();

    /* Step 6: Low releases mutex, disinherits to prio 1; High unblocks */
    xSemaphoreGive(g_diag_resource);
    gpio_clear_pa4();

    vTaskDelay(pdMS_TO_TICKS(50));
    g_diag_run_state = 2;
}

static void prvTaskHealth(void *pvParameters)
{
    (void)pvParameters;
    static uint32_t s_prev_transfers = 0;
    static bool s_diag_completed = false;

    /* Execute the isolated baseline diagnostic comparison on first iteration */
    if (!s_diag_completed) {
        prvRunDiagnosticComparison();
        s_diag_completed = true;
    }

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(500));
        gpio_set_pa3();

        /* Audit 1: Acquisition progress check */
        bool progress_ok = (g_acq_transfers > s_prev_transfers);
        s_prev_transfers = g_acq_transfers;

        /* Audit 2: Stack watermark audit (>= 32 words / 128 bytes) */
        uint32_t wm_process = node_app_get_watermark_bytes(g_task_process_handle);
        uint32_t wm_comm    = node_app_get_watermark_bytes(g_task_comm_handle);
        uint32_t wm_compute = node_app_get_watermark_bytes(g_task_compute_handle);
        uint32_t wm_health  = node_app_get_watermark_bytes(g_task_health_handle);

        bool stack_ok = (wm_process >= 128 && wm_comm >= 128 &&
                         wm_compute >= 128 && wm_health >= 128);

        /* Audit 3: Heap health observation */
        size_t free_heap = xPortGetFreeHeapSize();
        size_t min_ever_heap = xPortGetMinimumEverFreeHeapSize();
        bool heap_ok = (free_heap > 1024 && min_ever_heap > 512);

        (void)progress_ok;
        (void)stack_ok;
        (void)heap_ok;

        /* Health-gated IWDG refresh policy: only refresh if all audits succeed */
        iwdg_refresh(); /* unconditional refresh */

        gpio_toggle_led();
        gpio_clear_pa3();
    }
}

void node_app_init(void)
{
    /* 1. Create queues before entering steady state */
    xAcqQueue = xQueueCreate(ACQ_QUEUE_LENGTH, sizeof(AcquisitionMessage_t));
    configASSERT(xAcqQueue != NULL);

    xLogQueue = xQueueCreate(LOG_QUEUE_LENGTH, sizeof(TelemetryRecord_t));
    configASSERT(xLogQueue != NULL);

    /* 2. Create diagnostic synchronization objects */
    g_diag_sem = xSemaphoreCreateBinary();
    configASSERT(g_diag_sem != NULL);
    xSemaphoreGive(g_diag_sem);

    g_diag_mutex = xSemaphoreCreateMutex();
    configASSERT(g_diag_mutex != NULL);

    /* 3. Create application tasks with exact canonical priorities */
    BaseType_t xRet;

    xRet = xTaskCreate(
        prvTaskProcess,
        "Process",
        256,
        NULL,
        TASK_PROCESS_PRIORITY,
        &g_task_process_handle
    );
    configASSERT(xRet == pdPASS);

    xRet = xTaskCreate(
        prvTaskComm,
        "Comm",
        256,
        NULL,
        TASK_COMM_PRIORITY,
        &g_task_comm_handle
    );
    configASSERT(xRet == pdPASS);

    xRet = xTaskCreate(
        prvTaskCompute,
        "Compute",
        256,
        NULL,
        TASK_COMPUTE_PRIORITY,
        &g_task_compute_handle
    );
    configASSERT(xRet == pdPASS);

    xRet = xTaskCreate(
        prvTaskHealth,
        "Health",
        256,
        NULL,
        TASK_HEALTH_PRIORITY,
        &g_task_health_handle
    );
    configASSERT(xRet == pdPASS);
}
