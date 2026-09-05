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

    /*
     * SEEDED FAULT: MSIZE set to 0b00 (8-bit) while PSIZE is 0b01 (16-bit)
     * RM0008 Section 13.3.5: If MSIZE=8 and PSIZE=16, the DMA controller truncates
     * bits [15:8] and writes only the low byte to memory!
     */
    DMA1_Channel1->CCR = DMA_CCR_CIRC |
                         DMA_CCR_MINC |
                         DMA_CCR_PSIZE_0 |  /* 16-bit peripheral */
                         /* MSIZE left at 00: 8-bit memory */
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
