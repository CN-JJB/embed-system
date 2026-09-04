/**
 * =============================================================================
 * P2-M02 Challenge Reference: 4-Channel Direct-Register Software PWM
 * =============================================================================
 * Mechanism:
 *   - TIM2 running at 10 kHz periodic update interrupt (100 us resolution)
 *   - 100 steps per cycle -> 100 Hz PWM base frequency (10.0 ms period)
 *   - GPIOA PA0..PA3 updated atomically via BSRR / BRR registers
 *   - Zero HAL / CubeMX dependencies
 * =============================================================================
 */

#include "pwm.h"
#include "stm32f103xb.h"

static volatile uint8_t g_channel_duty[PWM_NUM_CHANNELS] = {0, 0, 0, 0};

bool pwm_init(uint32_t timclk_hz)
{
    if (timclk_hz == 0) {
        return false;
    }

    /* 1. Enable peripheral clocks for GPIOA (APB2) and TIM2 (APB1) */
    RCC->APB2ENR |= RCC_APB2ENR_IOPAEN;
    RCC->APB1ENR |= RCC_APB1ENR_TIM2EN;

    /* 2. Configure PA0, PA1, PA2, PA3 as Output Push-Pull 50 MHz
     *    CRL bits [15:0]: MODE=11 (50 MHz), CNF=00 (push-pull) -> 0x3333
     */
    GPIOA->CRL &= ~0x0000FFFFU;
    GPIOA->CRL |=  0x00003333U;

    /* Initialize all 4 pins to LOW atomically */
    GPIOA->BRR = 0x000FU;

    /* 3. Configure TIM2 for 10 kHz tick (100 us)
     *    Target: 10,000 updates/sec.
     *    Prescaler: prescale to 1 MHz (timclk / 1000000 - 1) -> 71 at 72 MHz
     *    ARR: 100 - 1 = 99 (100 us period)
     */
    uint32_t prescaler = (timclk_hz / 1000000U) - 1U;
    TIM2->CR1 = 0;
    TIM2->PSC = (uint16_t)prescaler;
    TIM2->ARR = (uint16_t)(PWM_STEPS - 1U); /* 99 -> 100 counts */
    TIM2->CNT = 0;

    /* Generate update event to load shadow registers */
    TIM2->EGR = TIM_EGR_UG;
    TIM2->SR = 0;

    /* 4. Enable TIM2 Update Interrupt in DIER and NVIC */
    TIM2->DIER |= TIM_DIER_UIE;

    /* NVIC Priority: set to 2 (upper 4 bits in Cortex-M3: 2 << 4 = 0x20) */
    NVIC->IP[TIM2_IRQn] = (uint8_t)(2U << 4);
    NVIC->ISER[TIM2_IRQn >> 5] = (1U << (TIM2_IRQn & 0x1FU));

    /* 5. Start TIM2 counter */
    TIM2->CR1 |= TIM_CR1_CEN;

    return true;
}

bool pwm_set_duty(uint8_t channel, uint8_t duty_percent)
{
    if (channel >= PWM_NUM_CHANNELS || duty_percent > PWM_STEPS) {
        return false;
    }
    g_channel_duty[channel] = duty_percent;
    return true;
}

uint8_t pwm_get_duty(uint8_t channel)
{
    if (channel >= PWM_NUM_CHANNELS) {
        return 0xFF;
    }
    return g_channel_duty[channel];
}

uint8_t pwm_step(void)
{
    static uint8_t step = 0;
    uint32_t set_mask = 0;
    uint32_t rst_mask = 0;

    for (uint8_t ch = 0; ch < PWM_NUM_CHANNELS; ch++) {
        if (step < g_channel_duty[ch]) {
            set_mask |= (1U << ch);
        } else {
            rst_mask |= (1U << ch);
        }
    }

    /* Atomic GPIO output updates */
    if (set_mask) {
        GPIOA->BSRR = set_mask;
    }
    if (rst_mask) {
        GPIOA->BRR = rst_mask;
    }

    uint8_t current_step = step;
    step++;
    if (step >= PWM_STEPS) {
        step = 0;
    }
    return current_step;
}

void TIM2_IRQHandler(void)
{
    if (TIM2->SR & TIM_SR_UIF) {
        /* Clear interrupt flag */
        TIM2->SR = (uint16_t)~TIM_SR_UIF;
        (void)TIM2->SR; /* Read back to ensure register write commits */

        pwm_step();
    }
}
