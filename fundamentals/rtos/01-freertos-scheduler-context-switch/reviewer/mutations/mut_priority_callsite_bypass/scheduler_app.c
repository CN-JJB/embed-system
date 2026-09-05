/**
 * =============================================================================
 * Defective Mutation: mut_priority_callsite_bypass
 * =============================================================================
 * Defect:
 * Header defines TASK_A_PRIORITY > TASK_B_PRIORITY (passing compile-time assertion),
 * but Task_B xTaskCreate() call-site uses (TASK_A_PRIORITY + 1), inverting actual
 * runtime priority so Task_B preempts Task_A.
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
        GPIOA->BSRR = (1 << 1);
        vTaskDelay(pdMS_TO_TICKS(5));
        GPIOA->BRR = (1 << 1);
        vTaskDelay(pdMS_TO_TICKS(5));
    }
}

static void prvTaskB(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        GPIOA->BSRR = (1 << 2);
        for (volatile uint32_t i = 0; i < 5000; i++) {
            __NOP();
        }
        GPIOA->BRR = (1 << 2);
        for (volatile uint32_t i = 0; i < 5000; i++) {
            __NOP();
        }
    }
}

int scheduler_app_init_and_start(clock_profile_t profile)
{
    /* 1. Initialize clock tree */
    if (!clock_init(profile)) {
        if (!clock_init(CLOCK_PROFILE_64MHZ_HSI)) {
            return -1;
        }
    }

    /* 2. Initialize GPIO */
    gpio_init();

    /* 3. Create Task_A */
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

    /* 4. Create Task_B with (TASK_A_PRIORITY + 1) instead of TASK_B_PRIORITY */
    xResult = xTaskCreate(
        prvTaskB,
        "Task_B",
        TASK_STACK_SIZE_WORDS,
        NULL,
        (TASK_A_PRIORITY + 1),
        &s_task_b_handle
    );
    if (xResult != pdPASS) {
        return -3;
    }

    /* 5. Start scheduler */
    vTaskStartScheduler();

    return -4;
}
