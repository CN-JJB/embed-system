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
     * 3. Decouple Master Mode Selection (MMS) during initialization preload:
     *    Keep MMS cleared (0b000) so that software update generation (UG) does NOT
     *    emit a TRGO pulse to ADC1 while the system remains in the quiescent diagnostic phase.
     */
    TIM3->CR2 &= ~TIM_CR2_MMS;
    TIM3->CR2 |= TIM_CR2_MMS_1;

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
    TIM3->CR2 &= ~TIM_CR2_MMS;
    TIM3->CR2 |= TIM_CR2_MMS_1;  /* 0b010 = Update */

    /* Enable counter */
    TIM3->CR1 |= TIM_CR1_CEN;
}

void tim3_trgo_stop(void)
{
    TIM3->CR1 &= ~TIM_CR1_CEN;
    TIM3->CR2 &= ~TIM_CR2_MMS;
}


