/**
 * =============================================================================
 * TIM3 TRGO Master Trigger Implementation for STM32F103C8T6
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M03 Peripheral Acquisition, ADC Sampling Contract, and DMA Data Path
 * =============================================================================
 */

#include "timer.h"
#include "stm32f103xb.h"

void tim3_trgo_init_10khz(uint32_t tim_clock_hz)
{
    /* 1. Enable TIM3 APB1 peripheral clock */
    RCC->APB1ENR |= RCC_APB1ENR_TIM3EN;

    /*
     * 2. Configure Prescaler and Auto-Reload for 10,000 updates/sec (10 kHz):
     *    Target counter tick rate = 1 MHz:
     *      PSC = (tim_clock_hz / 1,000,000) - 1
     *      Under 72 MHz: PSC = 72 - 1 = 71
     *      Under 64 MHz: PSC = 64 - 1 = 63
     *    Target update period = 100 us (10 kHz):
     *      ARR = (1,000,000 / 10,000) - 1 = 100 - 1 = 99
     */
    uint32_t psc = (tim_clock_hz / 1000000U) - 1U;
    uint32_t arr = (1000000U / 10000U) - 1U;

    TIM3->PSC = psc;
    TIM3->ARR = arr;

    /*
     * 3. Configure Master Mode Selection (MMS) in CR2:
     *    MMS[2:0] = 0b010: The Update event is selected as Trigger Output (TRGO).
     *    This signal connects directly to ADC1 regular external trigger (EXTSEL=100).
     */
    TIM3->CR2 &= ~TIM_CR2_MMS;
    TIM3->CR2 |= TIM_CR2_MMS_1;  /* 0b010 = Update */

    /* 4. Generate an update event to pre-load PSC and ARR shadow registers */
    TIM3->EGR = TIM_EGR_UG;
    TIM3->SR = 0; /* Clear update flag */

    /* 5. Start TIM3 counter */
    TIM3->CR1 |= TIM_CR1_CEN;
}
