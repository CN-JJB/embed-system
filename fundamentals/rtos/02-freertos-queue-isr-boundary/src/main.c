/**
 * =============================================================================
 * P2-M05: FreeRTOS Queue, Mutex, and ISR-Safe Synchronization Boundaries
 * =============================================================================
 * Demonstrates:
 *  - TIM2 ISR posting sequence numbers via xQueueSendFromISR()
 *  - Higher-priority Task_Consumer unblocking and verifying sequence continuity
 *  - portYIELD_FROM_ISR() deferred PendSV context switch
 *  - Cortex-M3 NVIC/BASEPRI priority contracts (logical 6 vs limit 5)
 * =============================================================================
 */

#include "clock.h"
#include "gpio.h"
#include "timer.h"
#include "queue_app.h"
#include "FreeRTOS.h"
#include "task.h"
#include "core_cm3.h"

int main(void)
{
    /* 1. Initialize clock tree (72 MHz HSE / 64 MHz HSI fallback) */
    clock_init(CLOCK_PROFILE_72MHZ_HSE);

    /* 2. Initialize GPIO markers (PA1: ISR, PA2: Task, PC13: LED) */
    gpio_init();

    /* 3. Configure Cortex-M3 priority grouping:
     * Group 0 ensures all 4 bits in IPR are pre-emption priority bits.
     */
    NVIC_SetPriorityGrouping(0);

    /* 4. Initialize Queue and Consumer task */
    queue_app_init();

    /* 5. Initialize TIM2 for 100 Hz periodic ISR at CMSIS logical priority 6 */
    timer2_init(100);
    timer2_start();

    /* 6. Start the FreeRTOS Preemptive Scheduler */
    vTaskStartScheduler();

    /* Should never reach here unless heap is exhausted */
    while (1) {
        __NOP();
    }

    return 0;
}
