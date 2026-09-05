#include <stdint.h>
#include "stm32f103xb.h"

volatile uint16_t g_adc_buffer[2][64];

void dma_width_fault_init(void)
{
    RCC->AHBENR |= RCC_AHBENR_DMA1EN;
    DMA1_Channel1->CCR &= ~DMA_CCR_EN;
    DMA1_Channel1->CPAR = (uint32_t)&(ADC1->DR);
    DMA1_Channel1->CMAR = (uint32_t)g_adc_buffer;
    DMA1_Channel1->CNDTR = 128;

    DMA1_Channel1->CCR = DMA_CCR_CIRC |
                         DMA_CCR_MINC |
                         DMA_CCR_PSIZE_0 |
                         DMA_CCR_HTIE |
                         DMA_CCR_TCIE;

    DMA1_Channel1->CCR |= DMA_CCR_EN;
}

int main(void)
{
    dma_width_fault_init();
    while (1) {
        __NOP();
    }
}
