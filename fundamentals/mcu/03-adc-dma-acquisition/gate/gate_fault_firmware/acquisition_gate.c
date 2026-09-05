#include <stdint.h>
#include "stm32f103xb.h"
#include "core_cm3.h"

volatile uint16_t g_adc_gate_buffer[2][64] __attribute__((aligned(4)));
volatile uint32_t g_gate_ht_count = 0;
volatile uint32_t g_gate_tc_count = 0;

void gate_dma_init(void)
{
    RCC->AHBENR |= RCC_AHBENR_DMA1EN;
    DMA1_Channel1->CCR &= ~DMA_CCR_EN;
    DMA1_Channel1->CPAR = (uint32_t)&(ADC1->DR);
    DMA1_Channel1->CMAR = (uint32_t)g_adc_gate_buffer;
    DMA1_Channel1->CNDTR = 128;
    DMA1_Channel1->CCR = DMA_CCR_CIRC |
                         DMA_CCR_MINC |
                         DMA_CCR_PSIZE_0 |
                         DMA_CCR_MSIZE_0 |
                         DMA_CCR_HTIE |
                         DMA_CCR_TCIE |
                         DMA_CCR_EN;
    NVIC_SetPriority(DMA1_Channel1_IRQn, 5);
    NVIC_EnableIRQ(DMA1_Channel1_IRQn);
}

int gate_adc_init(void)
{
    RCC->APB2ENR |= RCC_APB2ENR_ADC1EN | RCC_APB2ENR_IOPAEN;
    RCC->CFGR &= ~RCC_CFGR_ADCPRE;
    RCC->CFGR |= RCC_CFGR_ADCPRE_DIV6;

    GPIOA->CRL &= ~(GPIO_CRL_MODE0 | GPIO_CRL_CNF0);
    GPIOA->CRL |= (GPIO_CRL_MODE3_0 | GPIO_CRL_MODE3_1 | GPIO_CRL_MODE4_0 | GPIO_CRL_MODE4_1);

    ADC1->SMPR2 &= ~ADC_SMPR2_SMP0;
    ADC1->SMPR2 |= (ADC_SMPR2_SMP0_0 | ADC_SMPR2_SMP0_2);
    ADC1->SQR1 &= ~ADC_SQR1_L;
    ADC1->SQR3 &= ~ADC_SQR3_SQ1;

    ADC1->CR2 |= ADC_CR2_ADON;
    for (volatile uint32_t i = 0; i < 1000; i++) __NOP();

    ADC1->CR2 |= ADC_CR2_RSTCAL;
    while (ADC1->CR2 & ADC_CR2_RSTCAL);

    ADC1->CR2 |= ADC_CR2_CAL;
    while (ADC1->CR2 & ADC_CR2_CAL);

    ADC1->CR2 &= ~ADC_CR2_EXTSEL;
    ADC1->CR2 |= ADC_CR2_EXTSEL_2 | ADC_CR2_EXTTRIG | ADC_CR2_DMA;
    return 0;
}

void gate_tim3_init(void)
{
    RCC->APB1ENR |= RCC_APB1ENR_TIM3EN;
    TIM3->PSC = 71;
    TIM3->ARR = 99;
    TIM3->CR2 &= ~TIM_CR2_MMS;
    TIM3->CR2 |= TIM_CR2_MMS_1;    /* MMS = 0b010 (Update) */

    /*
     * SEEDED GATE DEFECT: TIM_CR1_UDIS (Update Disable) is set in CR1!
     * RM0008 Section 14.4.1: When UDIS=1, Update Events (UEV) are disabled.
     * The counter increments and wraps, but never generates an update event,
     * suppressing TRGO pulses.
     */
    TIM3->CR1 = TIM_CR1_CEN | TIM_CR1_UDIS;
}

void DMA1_Channel1_IRQHandler(void)
{
    uint32_t isr = DMA1->ISR;
    if (isr & DMA_ISR_HTIF1) {
        DMA1->IFCR = DMA_IFCR_CHTIF1;
        GPIOA->BSRR = (1 << 3);
        g_gate_ht_count++;
        GPIOA->BRR = (1 << 3);
    }
    if (isr & DMA_ISR_TCIF1) {
        DMA1->IFCR = DMA_IFCR_CTCIF1;
        GPIOA->BSRR = (1 << 4);
        g_gate_tc_count++;
        GPIOA->BRR = (1 << 4);
    }
    __DSB();
}

int main(void)
{
    gate_dma_init();
    gate_adc_init();
    gate_tim3_init();

    while (1) {
        __WFI();
    }
}
