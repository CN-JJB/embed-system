#include "dma.h"
#include "stm32f103xb.h"
#include "core_cm3.h"

volatile uint16_t g_adc_buffer[2][ADC_BUFFER_HALF_SIZE] __attribute__((aligned(4)));

volatile uint32_t g_dma_ht_count = 0;
volatile uint32_t g_dma_tc_count = 0;
volatile uint32_t g_dma_te_count = 0;

void dma1_channel1_init(void)
{
    /* 1. Enable AHB peripheral clock gate for DMA1 */
    RCC->AHBENR |= RCC_AHBENR_DMA1EN;

    /* 2. Ensure channel is disabled before modifying configuration registers */
    DMA1_Channel1->CCR &= ~DMA_CCR_EN;

    /* 3. Configure Peripheral Address (ADC1 Data Register) */
    DMA1_Channel1->CPAR = (uint32_t)&(ADC1->DR);

    /* 4. Configure Memory Destination Address (Persistent static SRAM buffer) */
    DMA1_Channel1->CMAR = (uint32_t)g_adc_buffer;

    /* 5. Set Number of Data items to transfer before reload (128 samples total) */
    DMA1_Channel1->CNDTR = ADC_BUFFER_TOTAL_SIZE;

    /*
     * 6. Configure Channel 1 Control Register (CCR):
     *    Peripheral-to-memory transfer with 16-bit word size and interrupt enables.
     */
    DMA1_Channel1->CCR = DMA_CCR_CIRC |
                         DMA_CCR_PSIZE_0 |
                         DMA_CCR_MSIZE_0 |
                         DMA_CCR_HTIE |
                         DMA_CCR_TCIE |
                         DMA_CCR_TEIE;

    /* 7. Configure NVIC Priority and enable IRQ */
    NVIC_SetPriority(DMA1_Channel1_IRQn, 5);
    NVIC_EnableIRQ(DMA1_Channel1_IRQn);

    /* 8. Enable DMA1 Channel 1 */
    DMA1_Channel1->CCR |= DMA_CCR_EN;
}

void DMA1_Channel1_IRQHandler(void)
{
    uint32_t isr_flags = DMA1->ISR;

    if (isr_flags & DMA_ISR_TEIF1) {
        DMA1->IFCR = DMA_IFCR_CTEIF1;
        g_dma_te_count++;
    }

    if (isr_flags & DMA_ISR_HTIF1) {
        DMA1->IFCR = DMA_IFCR_CHTIF1;
        g_dma_ht_count++;
    }

    if (isr_flags & DMA_ISR_TCIF1) {
        DMA1->IFCR = DMA_IFCR_CTCIF1;
        g_dma_tc_count++;
    }

    __DSB();
}
