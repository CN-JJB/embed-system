/**
 * =============================================================================
 * TIM3 1 kHz TRGO Master Trigger Implementation for STM32F103C8T6
 * =============================================================================
 * Course: Embedded Systems Foundations - Phase 2 MCU & FreeRTOS
 * Project: P2-M07 STM32 FreeRTOS Acquisition Node Integration Project
 * =============================================================================
 */

#include "timer.h"
#include "stm32f103xb.h"

void tim3_trgo_init_1khz(uint32_t tim_clock_hz)
{
    /* 1. Enable TIM3 APB1 peripheral clock gate */
    RCC->APB1ENR |= RCC_APB1ENR_TIM3EN;

    /*
     * 2. Configure Prescaler and Auto-Reload for 1.0 kHz periodic rate:
     *    Target counter tick rate = 1 MHz:
     *      PSC = (tim_clock_hz / 1,000,000) - 1
     *      Under 72 MHz: PSC = 72 - 1 = 71
     *      Under 64 MHz: PSC = 64 - 1 = 63
     *    Target update period = 1000 us (1.0 kHz):
     *      ARR = (1,000,000 / 1,000) - 1 = 1000 - 1 = 999
     */
    uint32_t psc = (tim_clock_hz / 1000000U) - 1U;
    uint32_t arr = 999U;

    TIM3->PSC = psc;
    TIM3->ARR = arr;

    /*
     * 3. Prevent TRGO trigger pulse emission during initialization preload:
     *    Per STM32F1 RM0008 Section 15.4.2 (TIMx_CR2 MMS[2:0]):
     *      - MMS=000 (Reset): The UG bit from TIMx_EGR is used as TRGO!
     *      - MMS=010 (Update): The Update event is used as TRGO.
     *      - MMS=001 (Enable): The Counter Enable signal (CEN) is used as TRGO.
     *    Because CEN=0 at this initialization stage, setting MMS=001 holds TRGO
     *    strictly low/inactive. Generating a software update (TIM_EGR_UG) preloads
     *    PSC and ARR shadow registers WITHOUT emitting any trigger pulse onto TRGO
     *    before the diagnostic phase completes.
     */
    TIM3->CR2 &= ~TIM_CR2_MMS;

    /* 4. Generate an update event to pre-load PSC and ARR shadow registers */
    TIM3->EGR = TIM_EGR_UG;
    TIM3->SR = 0; /* Clear update flag */
}

void tim3_trgo_start(void)
{
    /*
     * Configure Master Mode Selection (MMS) in CR2:
     * MMS[2:0] = 0b010: The Update event is selected as Trigger Output (TRGO).
     * This signal connects directly to ADC1 regular external trigger (EXTSEL=100).
     */
    TIM3->CR2 = (TIM3->CR2 & ~TIM_CR2_MMS) | TIM_CR2_MMS_1;  /* 0b010 = Update */

    /* Enable counter */
    TIM3->CR1 |= TIM_CR1_CEN;
}

void tim3_trgo_stop(void)
{
    TIM3->CR1 &= ~TIM_CR1_CEN;
    TIM3->CR2 = (TIM3->CR2 & ~TIM_CR2_MMS) | TIM_CR2_MMS_0;
}
