/**
 * =============================================================================
 * P2-M04 Main Application: FreeRTOS Scheduler and Context Switch Core
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M04 FreeRTOS Scheduler, Task Lifecycle, and Context Switch
 *
 * Architecture:
 *   - Pinned FreeRTOS Kernel V11.3.0 (commit 9b777ae)
 *   - heap_4 dynamic memory management (sole application heap)
 *   - Task_A: Priority 2 (High), toggles PA1, blocks via vTaskDelay(5 ms)
 *   - Task_B: Priority 1 (Low), toggles PA2, CPU-runnable workload
 *   - Context switch: PendSV assembly handler saves/restores r4-r11 on PSP
 * =============================================================================
 */

#include "FreeRTOS.h"
#include "task.h"
#include "clock.h"
#include "gpio.h"
#include "stm32f103xb.h"
#include "core_cm3.h"

#define TASK_A_STACK_SIZE   128
#define TASK_B_STACK_SIZE   128

#define TASK_A_PRIORITY     (tskIDLE_PRIORITY + 2)
#define TASK_B_PRIORITY     (tskIDLE_PRIORITY + 1)

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

int main(void)
{
    /* 1. Initialize clock tree: 72 MHz HSE primary or 64 MHz HSI fallback */
    if (!clock_init(CLOCK_PROFILE_72MHZ_HSE)) {
        if (!clock_init(CLOCK_PROFILE_64MHZ_HSI)) {
            while (1) {
                __NOP();
            }
        }
    }

    /* 2. Initialize GPIO pins (PA1 Task_A marker, PA2 Task_B marker, PC13 User LED) */
    gpio_init();

    /* 3. Create Task_A (Priority 2) */
    BaseType_t xResult = xTaskCreate(
        prvTaskA,
        "Task_A",
        TASK_A_STACK_SIZE,
        NULL,
        TASK_A_PRIORITY,
        &s_task_a_handle
    );
    configASSERT(xResult == pdPASS);

    /* 4. Create Task_B (Priority 1) */
    xResult = xTaskCreate(
        prvTaskB,
        "Task_B",
        TASK_B_STACK_SIZE,
        NULL,
        TASK_B_PRIORITY,
        &s_task_b_handle
    );
    configASSERT(xResult == pdPASS);

    /* Turn on PC13 User LED to indicate scheduler launch */
    GPIOC->BRR = GPIO_BRR_BR13;

    /*
     * 5. Start the FreeRTOS Scheduler:
     *    - Configures SysTick and PendSV priority in SCB->SHPR.
     *    - Calls prvPortStartFirstTask() which executes SVC 0.
     *    - vPortSVCHandler loads initial PSP for the highest priority ready task (Task_A).
     *    - Switches CPU Thread mode to use PSP and branches into prvTaskA.
     */
    vTaskStartScheduler();

    /* Should never reach here unless heap was exhausted during idle task creation */
    while (1) {
        __NOP();
    }

    return 0;
}
