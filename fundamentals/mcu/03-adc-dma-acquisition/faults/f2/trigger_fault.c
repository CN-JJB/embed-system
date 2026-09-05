#include <stdint.h>
#include "stm32f103xb.h"

int adc_trigger_fault_init(void)
{
    RCC->APB2ENR |= RCC_APB2ENR_ADC1EN | RCC_APB2ENR_IOPAEN;
    RCC->CFGR |= RCC_CFGR_ADCPRE_DIV6;
    GPIOA->CRL &= ~(GPIO_CRL_MODE0 | GPIO_CRL_CNF0);

    ADC1->CR2 |= ADC_CR2_ADON;
    for (volatile uint32_t i = 0; i < 1000; i++) __NOP();

    ADC1->CR2 |= ADC_CR2_RSTCAL;
    while (ADC1->CR2 & ADC_CR2_RSTCAL);

    ADC1->CR2 |= ADC_CR2_CAL;
    while (ADC1->CR2 & ADC_CR2_CAL);

    /*
     * SEEDED FAULT: EXTSEL configured with 0b000 (TIM1_CC1) instead of 0b100 (TIM3_TRGO)
     * Even though EXTTRIG is enabled, no trigger edge ever arrives from TIM1!
     */
    ADC1->CR2 &= ~ADC_CR2_EXTSEL; /* 0b000: TIM1_CC1 */
    ADC1->CR2 |= ADC_CR2_EXTTRIG | ADC_CR2_DMA;

    return 0;
}

int main(void)
{
    adc_trigger_fault_init();
    while (1) {
        __NOP();
    }
}
