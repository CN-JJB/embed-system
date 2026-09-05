/**
 * =============================================================================
 * Challenge Reference Solution: FreeRTOS Scheduler and Context Switch Core
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M04 FreeRTOS Scheduler, Task Lifecycle, and Context Switch
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

    for (;;) {
        /* Assert PA1 marker HIGH */
        GPIOA->BSRR = (1 << 1);

        /* Block for 5 ms, transitioning to Blocked list and yielding CPU to Task_B */
        vTaskDelay(pdMS_TO_TICKS(5));

        /* Deassert PA1 marker LOW */
        GPIOA->BRR = (1 << 1);

        vTaskDelay(pdMS_TO_TICKS(5));
    }
}

static void prvTaskB(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        /* Assert PA2 marker HIGH */
        GPIOA->BSRR = (1 << 2);

        /* CPU-runnable burn loop */
        for (volatile uint32_t i = 0; i < 5000; i++) {
            __NOP();
        }

        /* Deassert PA2 marker LOW */
        GPIOA->BRR = (1 << 2);

        for (volatile uint32_t i = 0; i < 5000; i++) {
            __NOP();
        }
    }
}

int scheduler_app_init_and_start(clock_profile_t profile)
{
    /* 1. Initialize clock tree with requested profile or fallback to 64 MHz HSI */
    if (!clock_init(profile)) {
        if (!clock_init(CLOCK_PROFILE_64MHZ_HSI)) {
            return -1;
        }
    }

    /* 2. Initialize GPIO pins (PA1 Task_A marker, PA2 Task_B marker) */
    gpio_init();

    /* 3. Create Task_A (Priority 2, 128 words stack) */
    BaseType_t xResult = xTaskCreate(
        prvTaskA,
        "Task_A",
        TASK_STACK_SIZE_WORDS,
        NULL,
        TASK_A_PRIORITY,
        &s_task_a_handle
    );
    if (xResult != pdPASS) {
        return -2;
    }

    /* 4. Create Task_B (Priority 1, 128 words stack) */
    xResult = xTaskCreate(
        prvTaskB,
        "Task_B",
        TASK_STACK_SIZE_WORDS,
        NULL,
        TASK_B_PRIORITY,
        &s_task_b_handle
    );
    if (xResult != pdPASS) {
        return -3;
    }

    /* 5. Start the FreeRTOS Scheduler */
    vTaskStartScheduler();

    /* Unreachable unless heap was exhausted */
    return 0;
}
