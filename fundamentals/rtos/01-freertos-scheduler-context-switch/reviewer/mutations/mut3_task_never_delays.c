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
        for (volatile uint32_t i = 0; i < 1000; i++) { __NOP(); }
        GPIOA->BRR = (1 << 1);
        for (volatile uint32_t i = 0; i < 1000; i++) { __NOP(); }
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
    if (!clock_init(profile)) {
        if (!clock_init(CLOCK_PROFILE_64MHZ_HSI)) {
            return -1;
        }
    }

    gpio_init();

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

    vTaskStartScheduler();
    return 0;
}
