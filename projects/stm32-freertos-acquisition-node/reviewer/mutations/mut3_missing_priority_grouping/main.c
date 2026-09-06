/**
 * =============================================================================
 * Main Integration Entry Point for STM32F103C8T6 FreeRTOS Acquisition Node
 * =============================================================================
 * Course: Embedded Systems Foundations - Phase 2 MCU & FreeRTOS
 * Project: P2-M07 STM32 FreeRTOS Acquisition Node Integration Project
 * =============================================================================
 */

#include "stm32f103xb.h"
#include "core_cm3.h"
#include "clock.h"
#include "gpio.h"
#include "usart.h"
#include "timer.h"
#include "adc.h"
#include "dma.h"
#include "iwdg.h"
#include "dwt.h"
#include "node_app.h"
#include "FreeRTOS.h"
#include "task.h"

int main(void)
{
    /*
     * 1. Configure Cortex-M3 NVIC Priority Grouping:
     *    NVIC_SetPriorityGrouping(0) assigns 4 bits to preemption priority
     *    and 0 bits to sub-priority. This is strictly required by FreeRTOS.
     */
    /* NVIC_SetPriorityGrouping(0) omitted */

    /* 2. Configure System Clock to 72 MHz using external 8 MHz HSE crystal */
    clock_init(CLOCK_PROFILE_72MHZ_HSE);

    /* 3. Inspect and clear reset cause flags (e.g. IWDG reset detection) */
    bool was_iwdg_reset = iwdg_check_and_clear_reset_cause();
    (void)was_iwdg_reset;

    /* 4. Initialize DWT cycle counter for sub-tick primary timing */
    dwt_init();

    /* 5. Initialize GPIO instrumentation and status pins */
    gpio_init();

    /* 6. Initialize USART1 at 115200 baud via direct CMSIS register driver */
    usart1_init(72000000U);

    /*
     * 7. Initialize Independent Watchdog (IWDG):
     *    Prescaler /64, reload 1250 gives ~2000 ms timeout under 40 kHz LSI.
     */
    iwdg_init(IWDG_PRESCALER_64, 1250);

    /* 8. Initialize ADC1 with TIM3 TRGO hardware trigger and DMA request */
    adc1_init(72000000U);

    /* 9. Initialize DMA1 Channel 1 for circular 128-sample double buffering */
    dma1_channel1_init();

    /* 10. Initialize TIM3 periodic 1.0 kHz master trigger generator (TRGO) */
    tim3_trgo_init_1khz(72000000U);

    /* 11. Create all application tasks, queues, and diagnostic primitives */
    node_app_init();

    /* 12. Start FreeRTOS preemptive scheduler */
    vTaskStartScheduler();

    /* Safety infinite loop: should never reach here unless heap is exhausted */
    for (;;) {
        __NOP();
    }

    return 0;
}
