#include <stdint.h>
#include "stm32f103xb.h"

void init_acquisition_with_stack_buffer(void)
{
    uint16_t local_stack_buffer[128];

    RCC->AHBENR |= RCC_AHBENR_DMA1EN;
    DMA1_Channel1->CCR &= ~DMA_CCR_EN;
    DMA1_Channel1->CPAR = (uint32_t)&(ADC1->DR);
    DMA1_Channel1->CMAR = (uint32_t)local_stack_buffer;
    DMA1_Channel1->CNDTR = 128;
    DMA1_Channel1->CCR = DMA_CCR_CIRC | DMA_CCR_MINC | DMA_CCR_PSIZE_0 | DMA_CCR_MSIZE_0 | DMA_CCR_EN;
}

uint32_t deep_worker_function(uint32_t a, uint32_t b)
{
    volatile uint32_t critical_state[32];
    for (int i = 0; i < 32; i++) {
        critical_state[i] = a + b + (uint32_t)i;
    }
    uint32_t sum = 0;
    for (int i = 0; i < 32; i++) {
        sum += critical_state[i];
    }
    return sum;
}

int main(void)
{
    init_acquisition_with_stack_buffer();
    volatile uint32_t result = deep_worker_function(0x1234, 0x5678);
    (void)result;
    while (1) {
        __NOP();
    }
}
