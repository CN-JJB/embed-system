#include "pwm.h"
#include "stm32f103xb.h"

static volatile uint8_t g_channel_duty[PWM_NUM_CHANNELS] = {0, 0, 0, 0};

bool pwm_init(uint32_t timclk_hz)
{
    if (timclk_hz == 0) return false;
    RCC->APB2ENR |= RCC_APB2ENR_IOPAEN;
    RCC->APB1ENR |= RCC_APB1ENR_TIM2EN;
    GPIOA->CRL &= ~0x0000FFFFU;
    GPIOA->CRL |=  0x00003333U;
    GPIOA->ODR &= ~0x000FU;

    uint32_t prescaler = (timclk_hz / 1000000U) - 1U;
    TIM2->CR1 = 0;
    TIM2->PSC = (uint16_t)prescaler;
    TIM2->ARR = (uint16_t)(PWM_STEPS - 1U);
    TIM2->CNT = 0;
    TIM2->EGR = TIM_EGR_UG;
    TIM2->SR = 0;

    TIM2->DIER |= TIM_DIER_UIE;
    NVIC->IP[TIM2_IRQn] = (uint8_t)(2U << 4);
    NVIC->ISER[TIM2_IRQn >> 5] = (1U << (TIM2_IRQn & 0x1FU));
    TIM2->CR1 |= TIM_CR1_CEN;
    return true;
}

bool pwm_set_duty(uint8_t channel, uint8_t duty_percent)
{
    if (channel >= PWM_NUM_CHANNELS || duty_percent > PWM_STEPS) return false;
    g_channel_duty[channel] = duty_percent;
    return true;
}

uint8_t pwm_get_duty(uint8_t channel)
{
    if (channel >= PWM_NUM_CHANNELS) return 0xFF;
    return g_channel_duty[channel];
}

uint8_t pwm_step(void)
{
    static uint8_t step = 0;

    /* MUTATION: Non-atomic RMW directly modifying GPIOA->ODR! */
    for (uint8_t ch = 0; ch < PWM_NUM_CHANNELS; ch++) {
        if (step < g_channel_duty[ch]) {
            GPIOA->ODR |= (1U << ch);
        } else {
            GPIOA->ODR &= ~(1U << ch);
        }
    }

    uint8_t current_step = step;
    step++;
    if (step >= PWM_STEPS) step = 0;
    return current_step;
}

void TIM2_IRQHandler(void)
{
    if (TIM2->SR & TIM_SR_UIF) {
        TIM2->SR = (uint16_t)~TIM_SR_UIF;
        (void)TIM2->SR;
        pwm_step();
    }
}
