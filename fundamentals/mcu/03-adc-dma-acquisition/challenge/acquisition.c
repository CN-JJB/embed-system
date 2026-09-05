/**
 * acquisition.c: Learner starter for P2-M03 Challenge
 * Complete the initialization sequence and ISR according to challenge specifications.
 */
#include "acquisition.h"
#include "stm32f103xb.h"
#include "core_cm3.h"

volatile uint16_t g_acq_buffer[2][ACQ_HALF_BUFFER_SIZE] __attribute__((aligned(4)));
volatile uint32_t g_acq_ht_events = 0;
volatile uint32_t g_acq_tc_events = 0;
volatile uint32_t g_acq_te_events = 0;

int acquisition_pipeline_init(uint32_t timclk_hz)
{
    /* TODO: Enable peripheral clocks for TIM3, ADC1, GPIOA, and DMA1 */

    /* TODO: Configure ADC prescaler in RCC->CFGR (/6) */

    /* TODO: Configure GPIOA: PA0 analog, PA3/PA4 push-pull outputs */

    /* TODO: Configure ADC1 SMP0 (55.5 cycles), sequence length = 1, channel 0 */

    /* TODO: Power on ADC1 and execute bounded RSTCAL / CAL sequence with timeout detection */

    /* TODO: Configure ADC1 EXTSEL for TIM3 TRGO, EXTTRIG, and DMA enable */

    /* TODO: Configure TIM3 PSC from timclk_hz and ARR for 10 kHz, MMS=010 Update, enable CEN */
    (void)timclk_hz;

    /* TODO: Configure DMA1 Channel 1: CPAR, CMAR, CNDTR=128, CIRC, MINC, 16-bit, HTIE, TCIE, TEIE, EN */

    /* TODO: Enable DMA1_Channel1_IRQn in NVIC */

    return 0;
}

void DMA1_Channel1_IRQHandler(void)
{
    /* TODO: Read DMA1->ISR, clear HTIF1/TCIF1/TEIF1 in DMA1->IFCR, pulse PA3/PA4, increment counters */
    __DSB();
}
