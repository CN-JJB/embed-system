/**
 * acquisition.c: Reference implementation for P2-M03 Challenge
 */
#include "acquisition.h"
#include "stm32f103xb.h"
#include "core_cm3.h"

volatile uint16_t g_acq_buffer[2][ACQ_HALF_BUFFER_SIZE] __attribute__((aligned(4)));
volatile uint32_t g_acq_ht_events = 0;
volatile uint32_t g_acq_tc_events = 0;

int acquisition_pipeline_init(uint32_t sysclk_hz)
{
    /* 1. Clock Gates */
    RCC->APB1ENR |= RCC_APB1ENR_TIM3EN;
    RCC->APB2ENR |= RCC_APB2ENR_ADC1EN | RCC_APB2ENR_IOPAEN;
    RCC->AHBENR  |= RCC_AHBENR_DMA1EN;

    /* 2. Configure ADC Prescaler: /6 ensures <= 14 MHz ceiling */
    RCC->CFGR &= ~RCC_CFGR_ADCPRE;
    RCC->CFGR |= RCC_CFGR_ADCPRE_DIV6;

    /* 3. Configure GPIO: PA0 Analog, PA3/PA4 Push-Pull Outputs */
    GPIOA->CRL &= ~(GPIO_CRL_MODE0 | GPIO_CRL_CNF0);
    GPIOA->CRL &= ~(GPIO_CRL_MODE3 | GPIO_CRL_CNF3 | GPIO_CRL_MODE4 | GPIO_CRL_CNF4);
    GPIOA->CRL |= (GPIO_CRL_MODE3_0 | GPIO_CRL_MODE3_1 | GPIO_CRL_MODE4_0 | GPIO_CRL_MODE4_1);
    GPIOA->BRR = (1 << 3) | (1 << 4);

    /* 4. Configure ADC1 Channel 0 Sample Time = 55.5 cycles */
    ADC1->SMPR2 &= ~ADC_SMPR2_SMP0;
    ADC1->SMPR2 |= (ADC_SMPR2_SMP0_0 | ADC_SMPR2_SMP0_2);

    /* Single regular conversion on Channel 0 */
    ADC1->SQR1 &= ~ADC_SQR1_L;
    ADC1->SQR3 &= ~ADC_SQR3_SQ1;

    /* 5. ADC1 Power-up and Hardware Calibration */
    ADC1->CR2 |= ADC_CR2_ADON;
    for (volatile uint32_t i = 0; i < 1000; i++) {
        __NOP();
    }

    ADC1->CR2 |= ADC_CR2_RSTCAL;
    uint32_t timeout = 100000;
    while (ADC1->CR2 & ADC_CR2_RSTCAL) {
        if (--timeout == 0) return -1;
    }

    ADC1->CR2 |= ADC_CR2_CAL;
    timeout = 100000;
    while (ADC1->CR2 & ADC_CR2_CAL) {
        if (--timeout == 0) return -2;
    }

    /* 6. ADC1 Trigger Routing: TIM3 TRGO & DMA request */
    ADC1->CR2 &= ~ADC_CR2_EXTSEL;
    ADC1->CR2 |= ADC_CR2_EXTSEL_2;  /* 0b100: TIM3_TRGO */
    ADC1->CR2 |= ADC_CR2_EXTTRIG;
    ADC1->CR2 |= ADC_CR2_DMA;

    /* 7. Configure TIM3 for 10 kHz Update TRGO */
    uint32_t psc = (sysclk_hz / 1000000U) - 1U;
    uint32_t arr = (1000000U / 10000U) - 1U;
    TIM3->PSC = psc;
    TIM3->ARR = arr;
    TIM3->CR2 &= ~TIM_CR2_MMS;
    TIM3->CR2 |= TIM_CR2_MMS_1;    /* 0b010: Update as TRGO */
    TIM3->EGR = TIM_EGR_UG;
    TIM3->SR = 0;
    TIM3->CR1 |= TIM_CR1_CEN;

    /* 8. Configure DMA1 Channel 1 */
    DMA1_Channel1->CCR &= ~DMA_CCR_EN;
    DMA1_Channel1->CPAR = (uint32_t)&(ADC1->DR);
    DMA1_Channel1->CMAR = (uint32_t)g_acq_buffer;
    DMA1_Channel1->CNDTR = ACQ_TOTAL_BUFFER_SIZE;
    DMA1_Channel1->CCR = DMA_CCR_CIRC |
                         DMA_CCR_MINC |
                         DMA_CCR_PSIZE_0 |
                         DMA_CCR_MSIZE_0 |
                         DMA_CCR_HTIE |
                         DMA_CCR_TCIE;

    NVIC_SetPriority(DMA1_Channel1_IRQn, 5);
    NVIC_EnableIRQ(DMA1_Channel1_IRQn);
    DMA1_Channel1->CCR |= DMA_CCR_EN;

    return 0;
}

void DMA1_Channel1_IRQHandler(void)
{
    uint32_t isr = DMA1->ISR;
    if (isr & DMA_ISR_HTIF1) {
        DMA1->IFCR = DMA_IFCR_CHTIF1;
        GPIOA->BSRR = (1 << 3);
        g_acq_ht_events++;
        GPIOA->BRR = (1 << 3);
    }
    if (isr & DMA_ISR_TCIF1) {
        DMA1->IFCR = DMA_IFCR_CTCIF1;
        GPIOA->BSRR = (1 << 4);
        g_acq_tc_events++;
        GPIOA->BRR = (1 << 4);
    }
    if (isr & DMA_ISR_TEIF1) {
        DMA1->IFCR = DMA_IFCR_CTEIF1;
    }
    __DSB();
}
