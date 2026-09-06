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
    NVIC_SetPriorityGrouping(0);

    /*
     * 2. Configure System Clock:
     *    Primary: 72 MHz SYSCLK via 8 MHz HSE crystal.
     *    Fallback: 64 MHz SYSCLK via 8 MHz internal HSI RC oscillator.
     *    If both clock initializations fail, trap CPU safely.
     */
    clock_init(CLOCK_PROFILE_72MHZ_HSE);

    /* Retrieve dynamically resolved peripheral bus frequencies */
    clock_frequencies_t freqs;
    clock_get_frequencies(&freqs);

    /* 3. Inspect and clear reset cause flags (e.g. IWDG reset detection) */
    bool was_iwdg_reset = iwdg_check_and_clear_reset_cause();
    (void)was_iwdg_reset;

    /* 4. Initialize DWT cycle counter for sub-tick primary timing */
    dwt_init();

    /* 5. Initialize GPIO instrumentation and status pins */
    gpio_init();

    /* 6. Initialize USART1 at 115200 baud via dynamic APB2 clock frequency */
    usart1_init(freqs.pclk2_hz);

    /*
     * 7. Initialize Independent Watchdog (IWDG):
     *    Prescaler /32, reload 1250 gives ~1000 ms nominal timeout under 40 kHz LSI (<= 1200 ms design target).
     *    If initialization fails (e.g. LSI or status register timeout), trap CPU safely.
     */
    if (!iwdg_init(IWDG_PRESCALER_32, 1250)) {
        __disable_irq();
        for (;;) {
            __NOP();
        }
    }

    /* 8. Initialize ADC1 with TIM3 TRGO hardware trigger and DMA request */
    adc1_init(freqs.pclk2_hz);

    /* 9. Initialize DMA1 Channel 1 for circular 128-sample double buffering */
    dma1_channel1_init();

    /*
     * 10. Configure TIM3 periodic 1.0 kHz master trigger generator (TRGO).
     *     Counter is kept stopped until diagnostic completes in Task_Health.
     */
    tim3_trgo_init_1khz(freqs.timclk1_hz);

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
