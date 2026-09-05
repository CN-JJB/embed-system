/**
 * =============================================================================
 * Defective Mutation: mut_stack_callsite_bypass
 * =============================================================================
 * Defect:
 * Header defines TASK_STACK_SIZE_WORDS = 128U (passing compile-time assertion),
 * but Task_A xTaskCreate() call-site uses a different 64-word macro BAD_STACK.
 * =============================================================================
 */

#include "scheduler_app.h"
#include "FreeRTOS.h"
#include "task.h"
#include "clock.h"
#include "gpio.h"
#include "stm32f103xb.h"

#define BAD_STACK 64U

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

    /* 3. Create Task_A with BAD_STACK instead of TASK_STACK_SIZE_WORDS */
    BaseType_t xResult = xTaskCreate(
        prvTaskA,
        "Task_A",
        BAD_STACK,
        NULL,
        TASK_A_PRIORITY,
        &s_task_a_handle
    );
    if (xResult != pdPASS) {
        return -2;
    }

    /* 4. Create Task_B */
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

    /* 5. Start scheduler */
    vTaskStartScheduler();

    return -4;
}
