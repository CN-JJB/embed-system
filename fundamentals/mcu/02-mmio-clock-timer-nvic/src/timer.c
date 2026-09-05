/**
 * =============================================================================
 * Hardware Timer (TIM2) Direct Register Implementation
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M02 MMIO, Clock Tree, Hardware Timers, and NVIC Mechanism
 *
 * Mathematical Derivation:
 *   Target update frequency: f_update = 1000 Hz (1.0 ms period)
 *   Timer clock: f_timclk (e.g. 72 MHz in primary profile)
 *   Formula:
 *     f_update = f_timclk / ((PSC + 1) * (ARR + 1))
 *
 *   For f_timclk = 72 MHz:
 *     (PSC + 1) * (ARR + 1) = 72,000,000 / 1000 = 72,000
 *     Choose PSC = 71  (PSC + 1 = 72 -> counter tick frequency = 1 MHz = 1 us)
 *     Choose ARR = 999 (ARR + 1 = 1000 -> 1000 * 1 us = 1.0 ms)
 *
 *   For f_timclk = 64 MHz (fallback):
 *     (PSC + 1) * (ARR + 1) = 64,000,000 / 1000 = 64,000
 *     Choose PSC = 63  (PSC + 1 = 64 -> counter tick frequency = 1 MHz = 1 us)
 *     Choose ARR = 999 (ARR + 1 = 1000 -> 1000 * 1 us = 1.0 ms)
 * =============================================================================
 */

#include "timer.h"
#include "gpio.h"
#include "stm32f103xb.h"
#include "core_cm3.h"

volatile uint32_t g_tim2_ticks = 0;

void tim2_init_1khz(uint32_t timclk_hz)
{
    /* 1. Enable TIM2 peripheral clock in RCC (APB1 bus) */
    RCC->APB1ENR |= RCC_APB1ENR_TIM2EN;

    /* 2. Derive prescaler (PSC) to produce a 1 MHz (1 us) counter clock */
    uint32_t psc_val = (timclk_hz / 1000000U) - 1U;
    uint32_t arr_val = 999U; /* 1000 ticks of 1 us = 1 ms (1 kHz) */

    TIM2->PSC = (uint16_t)psc_val;
    TIM2->ARR = (uint16_t)arr_val;

    /* 3. Re-initialize counter and generate update event to load registers */
    TIM2->EGR = TIM_EGR_UG;

    /* 4. Clear update interrupt flag (cleared by writing 0 to UIF) */
    TIM2->SR = ~TIM_SR_UIF;

    /* 5. Enable Update Interrupt in TIM2 DIER */
    TIM2->DIER |= TIM_DIER_UIE;

    /* 6. Configure NVIC Priority and Enable IRQ
     * STM32F103 implements 4 priority bits (__NVIC_PRIO_BITS = 4).
     * CMSIS logical priority 6 encodes as 0x60 in hardware byte.
     */
    NVIC_SetPriority(TIM2_IRQn, 6);
    NVIC_EnableIRQ(TIM2_IRQn);

    /* 7. Start the timer counter */
    TIM2->CR1 |= TIM_CR1_CEN;
}

/**
 * @brief TIM2 Interrupt Service Routine (ISR)
 *
 * Architectural Invariants:
 * 1. Must acknowledge and clear TIM_SR_UIF in peripheral register!
 *    Omitting this clear results in an immediate infinite interrupt storm
 *    where the CPU re-enters the ISR endlessly, starving Thread mode.
 * 2. Write buffer delay hazard:
 *    A Cortex-M3 write buffer can hold the register write while instructions
 *    continue. An explicit __DSB() ensures the peripheral acknowledges the
 *    flag clear before returning from the exception.
 * 3. Timing Marker:
 *    Toggles PA1 via atomic BSRR to provide physical oscilloscope evidence.
 */
void TIM2_IRQHandler(void)
{
    /* Check update interrupt flag */
    if (TIM2->SR & TIM_SR_UIF) {
        /* Acknowledge and clear flag */
        TIM2->SR = ~TIM_SR_UIF;

        /* Toggle GPIO PA1 timing marker atomically */
        gpio_toggle_pa1_atomic();

        /* Increment tick counter */
        g_tim2_ticks++;

        /* Data Synchronization Barrier: ensures write buffer drains */
        __DSB();
    }
}
