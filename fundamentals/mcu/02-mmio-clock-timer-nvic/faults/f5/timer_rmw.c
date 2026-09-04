#include "timer.h"
#include "gpio.h"
#include "stm32f103xb.h"
#include "core_cm3.h"

volatile uint32_t g_tim2_ticks = 0;

void tim2_init_1khz(uint32_t timclk_hz)
{
    RCC->APB1ENR |= RCC_APB1ENR_TIM2EN;

    uint32_t psc_val = (timclk_hz / 1000000U) - 1U;
    uint32_t arr_val = 999U;

    TIM2->PSC = (uint16_t)psc_val;
    TIM2->ARR = (uint16_t)arr_val;
    TIM2->EGR = TIM_EGR_UG;
    TIM2->SR = ~TIM_SR_UIF;
    TIM2->DIER |= TIM_DIER_UIE;

    NVIC_SetPriority(TIM2_IRQn, 6);
    NVIC_EnableIRQ(TIM2_IRQn);

    TIM2->CR1 |= TIM_CR1_CEN;
}

void TIM2_IRQHandler(void)
{
    if (TIM2->SR & TIM_SR_UIF) {
        TIM2->SR = ~TIM_SR_UIF;
        __DSB();

        /* Non-atomic RMW inside ISR: modifies shared GPIOA->ODR */
        GPIOA->ODR ^= GPIO_ODR_ODR1;
        g_tim2_ticks++;
    }
}
