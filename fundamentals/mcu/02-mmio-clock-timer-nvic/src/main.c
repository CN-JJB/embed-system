/**
 * =============================================================================
 * Main Application for Module P2-M02: MMIO, Clock, Timer, NVIC
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M02 MMIO, Clock Tree, Hardware Timers, and NVIC Mechanism
 *
 * Demonstrates:
 *   1. 72 MHz SYSCLK PLL configuration (or 64 MHz HSI fallback)
 *   2. TIM2 1 kHz periodic interrupt with direct register setup
 *   3. GPIO timing markers on PA1 (ISR) and PA2 (Thread mode RMW)
 *   4. Low-power idle state using WFI (Wait For Interrupt)
 * =============================================================================
 */

#include <stdint.h>
#include <stdbool.h>
#include "clock.h"
#include "timer.h"
#include "gpio.h"
#include "stm32f103xb.h"
#include "core_cm3.h"

int main(void)
{
    /* 1. Initialize clock tree (72 MHz primary profile with HSE) */
    clock_frequencies_t freqs;
    bool clock_ok = clock_init(CLOCK_PROFILE_72MHZ_HSE);
    if (!clock_ok) {
        /* Failed to lock HSE: safe fallback to 64 MHz HSI */
        clock_init(CLOCK_PROFILE_64MHZ_HSI);
    }
    clock_get_frequencies(&freqs);

    /* 2. Initialize GPIO test pins (PA1, PA2, PC13) */
    gpio_init();

    /* 3. Initialize TIM2 for 1 kHz periodic update interrupt */
    tim2_init_1khz(freqs.timclk1_hz);

    /* 4. Main Thread Execution:
     *    Wait for interrupts while exercising atomic vs non-atomic GPIO access.
     */
    uint32_t last_tick = 0;
    while (1) {
        /* Sleep core until next interrupt */
        __WFI();

        if (g_tim2_ticks != last_tick) {
            last_tick = g_tim2_ticks;

            /* Toggle User LED every 500 ms (1 Hz square-wave blink, 1.0 s period) */
            if ((last_tick % 500) == 0) {
                if (GPIOC->ODR & (1U << 13)) {
                    GPIOC->BRR = (1U << 13);  /* LED ON */
                } else {
                    GPIOC->BSRR = (1U << 13); /* LED OFF */
                }
            }

            /* Demonstrate atomic GPIO set on PA2 */
            gpio_toggle_pa2_atomic();
        }
    }

    return 0;
}
