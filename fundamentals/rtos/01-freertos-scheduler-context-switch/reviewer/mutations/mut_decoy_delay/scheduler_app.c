/**
 * =============================================================================
 * Defective Mutation: mut_decoy_delay
 * =============================================================================
 * Defect:
 * Calls vTaskDelay(pdMS_TO_TICKS(5)) inside an unused helper function, while
 * the actual prvTaskA task never calls vTaskDelay and starves lower priority tasks.
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

/* Unused decoy helper containing the required delay call */
void unused_decoy_helper(void)
{
    vTaskDelay(pdMS_TO_TICKS(5));
}

/* Actual prvTaskA never calls vTaskDelay */
static void prvTaskA(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        GPIOA->BSRR = (1 << 1);
        for (volatile uint32_t i = 0; i < 5000; i++) {
            __NOP();
        }
        GPIOA->BRR = (1 << 1);
        for (volatile uint32_t i = 0; i < 5000; i++) {
            __NOP();
        }
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
    (void)unused_decoy_helper;

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

    /* 5. Start FreeRTOS Scheduler */
    vTaskStartScheduler();

    return -4;
}
