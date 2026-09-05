/**
 * =============================================================================
 * P2-M06: Priority Inversion, Inheritance, Stack Watermark & Watchdog Recovery
 * =============================================================================
 * Demonstrates:
 *  - Deterministic 3-task priority inversion experiment (High 3, Med 2, Low 1)
 *  - Comparison: Binary Semaphore control vs Mutex with Priority Inheritance
 *  - Identical Low CPU workload (~5 ms, strictly no vTaskDelay in critical section)
 *  - Stack watermark monitoring (words to bytes) and overflow detection level 2
 *  - STM32F103 Independent Watchdog (IWDG) configuration and reset-cause audit
 * =============================================================================
 */

#include "clock.h"
#include "gpio.h"
#include "inversion_app.h"
#include "iwdg.h"
#include "FreeRTOS.h"
#include "task.h"
#include "core_cm3.h"

/* FAULT f5: Spawning an unmonitored high-priority task that blindly feeds the watchdog
 * even when application tasks are starved, deadlocked, or unresponsive! */
static void prvBlindWatchdogTask(void *pvParameters) {
    (void)pvParameters;
    for (;;) {
        iwdg_refresh();
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

int main(void)
{
    /* 1. Initialize clock tree (72 MHz HSE / 64 MHz HSI fallback) */
    clock_init(CLOCK_PROFILE_72MHZ_HSE);

    /* 2. Initialize diagnostic GPIO pins */
    gpio_init();

    /* 3. Configure Cortex-M3 priority grouping to 0 */
    NVIC_SetPriorityGrouping(0);

    /* 4. Check and record reset cause from RCC->CSR */
    bool was_iwdg_reset = iwdg_check_and_clear_reset_cause();
    (void)was_iwdg_reset;

    /* 5. Initialize IWDG with ~2 second nominal timeout (prescaler 4 = /64, reload 1250) */
    iwdg_init(4, 1250);

    xTaskCreate(prvBlindWatchdogTask, "WdgFeeder", 128, NULL, 4, NULL);

    /* 7. Start FreeRTOS preemptive scheduler */
    vTaskStartScheduler();

    while (1) {
        __NOP();
    }

    return 0;
}
