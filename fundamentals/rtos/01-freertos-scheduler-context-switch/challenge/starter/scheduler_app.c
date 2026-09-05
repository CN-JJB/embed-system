/**
 * =============================================================================
 * Challenge Starter: FreeRTOS Scheduler and Context Switch Integration
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M04 FreeRTOS Scheduler, Task Lifecycle, and Context Switch
 * =============================================================================
 * Instructions:
 * Complete the implementation of scheduler_app_init_and_start, Task_A, and Task_B.
 *
 * Requirements:
 * 1. Clock Initialization:
 *    - Initialize the system clock using the requested primary profile.
 *    - If primary profile fails, fall back to CLOCK_PROFILE_64MHZ_HSI.
 *    - If both fail, return -1.
 * 2. GPIO Initialization:
 *    - Call gpio_init() to configure PA1 (Task_A marker) and PA2 (Task_B marker).
 * 3. Task Creation:
 *    - Task_A: Priority 2, stack 128 words. Toggles PA1, enters Blocked state
 *      via periodic vTaskDelay(pdMS_TO_TICKS(5)).
 *    - Task_B: Priority 1, stack 128 words. Toggles PA2, performs CPU workload.
 *    - Return codes from xTaskCreate must be validated.
 * 4. Scheduler Startup:
 *    - Start scheduler via vTaskStartScheduler().
 * =============================================================================
 */

#include "scheduler_app.h"
#include "FreeRTOS.h"
#include "task.h"
#include "clock.h"
#include "gpio.h"
#include "stm32f103xb.h"

static TaskHandle_t s_task_a_handle = NULL;
static TaskHandle_t s_task_b_handle = NULL;

static void prvTaskA(void *pvParameters)
{
    (void)pvParameters;

    /* TODO: Implement periodic Task_A toggling PA1 with vTaskDelay(pdMS_TO_TICKS(5)) */
    for (;;) {
        __NOP();
    }
}

static void prvTaskB(void *pvParameters)
{
    (void)pvParameters;

    /* TODO: Implement CPU-runnable Task_B toggling PA2 while Task_A is blocked */
    for (;;) {
        __NOP();
    }
}

int scheduler_app_init_and_start(clock_profile_t profile)
{
    /* TODO:
     * 1. Initialize clock using profile, falling back to 64 MHz HSI.
     * 2. Call gpio_init().
     * 3. Create Task_A (Priority 2, 128 words).
     * 4. Create Task_B (Priority 1, 128 words).
     * 5. Call vTaskStartScheduler().
     */
    (void)profile;
    (void)s_task_a_handle;
    (void)s_task_b_handle;
    (void)prvTaskA;
    (void)prvTaskB;

    return -1;
}
