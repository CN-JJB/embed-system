/**
 * =============================================================================
 * Defective Mutation: mut_no_task_creation
 * =============================================================================
 * Defect:
 * Defines prvTaskA and prvTaskB, contains decoy pdPASS checks, and starts the
 * scheduler, but never calls xTaskCreate() for either task.
 * =============================================================================
 */

#include "scheduler_app.h"
#include "FreeRTOS.h"
#include "task.h"
#include "clock.h"
#include "gpio.h"
#include "stm32f103xb.h"

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
    /* Suppress unused function warnings */
    (void)prvTaskA;
    (void)prvTaskB;

    /* 1. Initialize clock tree */
    if (!clock_init(profile)) {
        if (!clock_init(CLOCK_PROFILE_64MHZ_HSI)) {
            return -1;
        }
    }

    /* 2. Initialize GPIO */
    gpio_init();

    /* Defect: decoy pdPASS checks, but no xTaskCreate calls */
    volatile BaseType_t decoy_res1 = pdPASS;
    volatile BaseType_t decoy_res2 = pdPASS;
    if (decoy_res1 != pdPASS || decoy_res2 != pdPASS) {
        return -2;
    }

    /* 3. Start scheduler without creating tasks */
    vTaskStartScheduler();

    return -4;
}
