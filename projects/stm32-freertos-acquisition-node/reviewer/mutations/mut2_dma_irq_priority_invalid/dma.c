/**
 * =============================================================================
 * DMA1 Channel 1 Circular Acquisition Implementation for STM32F103C8T6
 * =============================================================================
 * Course: Embedded Systems Foundations - Phase 2 MCU & FreeRTOS
 * Project: P2-M07 STM32 FreeRTOS Acquisition Node Integration Project
 * =============================================================================
 */

#include "dma.h"
#include "gpio.h"
#include "stm32f103xb.h"
#include "core_cm3.h"

/*
 * Persistent double-buffer in SRAM with static storage duration:
 *   - Half 0: g_adc_pool[0][0..63]
 *   - Half 1: g_adc_pool[1][0..63]
 */
volatile uint16_t g_adc_pool[2][ADC_BUFFER_HALF_SIZE] __attribute__((aligned(4)));

/* Diagnostic transfer and milestone counters */
volatile uint32_t g_dma_ht_count = 0;
volatile uint32_t g_dma_tc_count = 0;
volatile uint32_t g_dma_te_count = 0;
volatile uint32_t g_acq_sequence = 0;
volatile uint32_t g_acq_transfers = 0;
volatile uint32_t g_acq_drops = 0;

/* External FreeRTOS acquisition queue handle */
extern QueueHandle_t xAcqQueue;

void dma1_channel1_init(void)
{
    /* 1. Enable AHB peripheral clock gate for DMA1 */
    RCC->AHBENR |= RCC_AHBENR_DMA1EN;

    /* 2. Ensure channel is disabled before modifying configuration registers */
    DMA1_Channel1->CCR &= ~DMA_CCR_EN;

    /* 3. Configure Peripheral Address (ADC1 Data Register) */
    DMA1_Channel1->CPAR = (uint32_t)&(ADC1->DR);

    /* 4. Configure Memory Destination Address (Persistent static SRAM pool) */
    DMA1_Channel1->CMAR = (uint32_t)g_adc_pool;

    /* 5. Set Number of Data items to transfer before reload (128 samples total) */
    DMA1_Channel1->CNDTR = ADC_BUFFER_TOTAL_SIZE;

    /*
     * 6. Configure Channel 1 Control Register (CCR):
     *    - DIR   = 0   (Peripheral-to-Memory transfer)
     *    - CIRC  = 1   (Circular mode: CNDTR automatically reloaded on wrap)
     *    - PINC  = 0   (Peripheral address increment disabled: always read ADC1->DR)
     *    - MINC  = 1   (Memory address increment enabled: step across buffer)
     *    - PSIZE = 01  (16-bit peripheral data width matching 12-bit ADC DR)
     *    - MSIZE = 01  (16-bit memory data width matching uint16_t buffer)
     *    - HTIE  = 1   (Half-Transfer Complete Interrupt Enable)
     *    - TCIE  = 1   (Transfer Complete Interrupt Enable)
     *    - TEIE  = 1   (Transfer Error Interrupt Enable)
     */
    DMA1_Channel1->CCR = DMA_CCR_CIRC |
                         DMA_CCR_MINC |
                         DMA_CCR_PSIZE_0 |
                         DMA_CCR_MSIZE_0 |
                         DMA_CCR_HTIE |
                         DMA_CCR_TCIE |
                         DMA_CCR_TEIE;

    /*
     * 7. Configure NVIC Priority and enable IRQ:
     *    Logical priority 6 is strictly within the FreeRTOS syscall boundary (<= 5).
     */
    NVIC_SetPriority(DMA1_Channel1_IRQn, 4);
    NVIC_EnableIRQ(DMA1_Channel1_IRQn);

    /* 8. Enable DMA1 Channel 1 */
    DMA1_Channel1->CCR |= DMA_CCR_EN;
}

/**
 * @brief DMA1 Channel 1 Interrupt Service Routine.
 *
 * Emits token messages to xAcqQueue upon HT and TC milestones.
 * Strictly non-blocking, zero dynamic allocation, FreeRTOS FromISR API only.
 */
void DMA1_Channel1_IRQHandler(void)
{
    uint32_t isr = DMA1->ISR;
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    /* Half-Transfer Milestone: Half 0 (samples 0..63) completed */
    if (isr & DMA_ISR_HTIF1) {
        DMA1->IFCR = DMA_IFCR_CHTIF1;   /* Clear interrupt flag */
        gpio_toggle_pa1();

        AcquisitionMessage_t msg;
        msg.buffer_index = 0;
        msg.count = ADC_BUFFER_HALF_SIZE;
        msg.timestamp = xTaskGetTickCountFromISR();
        msg.sequence = g_acq_sequence++;

        if (xAcqQueue != NULL) {
            BaseType_t xResult = xQueueSendFromISR(xAcqQueue, &msg, &xHigherPriorityTaskWoken);
            if (xResult == pdPASS) {
                g_dma_ht_count++;
                g_acq_transfers++;
            } else {
                g_acq_drops++;
            }
        }
    }

    /* Transfer-Complete Milestone: Half 1 (samples 64..127) completed */
    if (isr & DMA_ISR_TCIF1) {
        DMA1->IFCR = DMA_IFCR_CTCIF1;   /* Clear interrupt flag */
        gpio_toggle_pa1();

        AcquisitionMessage_t msg;
        msg.buffer_index = 1;
        msg.count = ADC_BUFFER_HALF_SIZE;
        msg.timestamp = xTaskGetTickCountFromISR();
        msg.sequence = g_acq_sequence++;

        if (xAcqQueue != NULL) {
            BaseType_t xResult = xQueueSendFromISR(xAcqQueue, &msg, &xHigherPriorityTaskWoken);
            if (xResult == pdPASS) {
                g_dma_tc_count++;
                g_acq_transfers++;
            } else {
                g_acq_drops++;
            }
        }
    }

    /* Transfer Error Milestone: Bus error occurred during transfer */
    if (isr & DMA_ISR_TEIF1) {
        DMA1->IFCR = DMA_IFCR_CTEIF1;   /* Clear error flag */
        g_dma_te_count++;
    }

    /* Yield to high-priority Task_Process if unblocked by FromISR send */
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);

    /* Data Synchronization Barrier ensures peripheral flag clear drains before exit */
    __DSB();
}
