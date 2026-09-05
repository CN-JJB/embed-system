#include <stdint.h>
#include "stm32f103xb.h"

int adc_dma_req_fault_init(void)
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

    ADC1->CR2 &= ~ADC_CR2_EXTSEL;
    ADC1->CR2 |= ADC_CR2_EXTSEL_2 | ADC_CR2_EXTTRIG;

    return 0;
}

int main(void)
{
    adc_dma_req_fault_init();
    while (1) {
        __NOP();
    }
}
