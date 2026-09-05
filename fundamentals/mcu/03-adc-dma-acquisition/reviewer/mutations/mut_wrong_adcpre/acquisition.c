#include "acquisition.h"
#include "stm32f103xb.h"
#include "core_cm3.h"

volatile uint16_t g_acq_buffer[2][ACQ_HALF_BUFFER_SIZE] __attribute__((aligned(4)));
volatile uint32_t g_acq_ht_events = 0;
volatile uint32_t g_acq_tc_events = 0;
volatile uint32_t g_acq_te_events = 0;

int acquisition_pipeline_init(uint32_t timclk_hz)
{
    RCC->APB1ENR |= RCC_APB1ENR_TIM3EN;
    RCC->APB2ENR |= RCC_APB2ENR_ADC1EN | RCC_APB2ENR_IOPAEN;
    RCC->AHBENR  |= RCC_AHBENR_DMA1EN;

    /* MUTATION: ADCPRE set to DIV2 instead of DIV6 */
    RCC->CFGR &= ~RCC_CFGR_ADCPRE;
    RCC->CFGR |= RCC_CFGR_ADCPRE_DIV2;

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

    uint32_t psc = (timclk_hz / 1000000U) - 1U;
    uint32_t arr = (1000000U / 10000U) - 1U;
    TIM3->PSC = psc;
    TIM3->ARR = arr;
    TIM3->CR2 &= ~TIM_CR2_MMS;
    TIM3->CR2 |= TIM_CR2_MMS_1;
    TIM3->CR1 |= TIM_CR1_CEN;

    DMA1_Channel1->CCR &= ~DMA_CCR_EN;
    DMA1_Channel1->CPAR = (uint32_t)&(ADC1->DR);
    DMA1_Channel1->CMAR = (uint32_t)g_acq_buffer;
    DMA1_Channel1->CNDTR = ACQ_TOTAL_BUFFER_SIZE;
    DMA1_Channel1->CCR = DMA_CCR_CIRC | DMA_CCR_MINC | DMA_CCR_PSIZE_0 | DMA_CCR_MSIZE_0 | DMA_CCR_HTIE | DMA_CCR_TCIE | DMA_CCR_TEIE | DMA_CCR_EN;
    NVIC_SetPriority(DMA1_Channel1_IRQn, 5);
    NVIC_EnableIRQ(DMA1_Channel1_IRQn);
    return 0;
}

void DMA1_Channel1_IRQHandler(void)
{
    uint32_t isr = DMA1->ISR;
    if (isr & DMA_ISR_HTIF1) {
        DMA1->IFCR = DMA_IFCR_CHTIF1;
        g_acq_ht_events++;
    }
    if (isr & DMA_ISR_TCIF1) {
        DMA1->IFCR = DMA_IFCR_CTCIF1;
        g_acq_tc_events++;
    }
    if (isr & DMA_ISR_TEIF1) { DMA1->IFCR = DMA_IFCR_CTEIF1; g_acq_te_events++; }
    __DSB();
}
