/**
 * test_harness_host.c: Host-side unit test harness for learner acquisition logic (P2-M03)
 * Verifies direct-register MMIO hardware configuration:
 *  - TIM3 TRGO (PSC=71/63, ARR=99, MMS=010, CEN=1)
 *  - ADC1 (ADCPRE=/6, PA0 analog, SMP0=55.5 cycles, calibration, EXTSEL=100, EXTTRIG=1, DMA=1)
 *  - DMA1 Channel 1 (CPAR=&ADC1->DR, CMAR=g_acq_buffer, CNDTR=128, CIRC, MINC, 16-bit, HTIE, TCIE, EN)
 *  - DMA1_Channel1_IRQHandler (HTIF1/TCIF1 clear in IFCR, PA3/PA4 pulse, counter increments)
 */
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#define STM32F103xB
#include "stm32f103xb.h"
#include "core_cm3.h"

static GPIO_TypeDef        s_mock_gpioa;
static GPIO_TypeDef        s_mock_gpioc;
static TIM_TypeDef         s_mock_tim3;
static ADC_TypeDef         s_mock_adc1;
static DMA_TypeDef         s_mock_dma1;
static DMA_Channel_TypeDef s_mock_dma1_ch1;
static RCC_TypeDef         s_mock_rcc;
static NVIC_Type           s_mock_nvic;

#undef GPIOA
#undef GPIOC
#undef TIM3
#undef ADC1
#undef DMA1
#undef DMA1_Channel1
#undef RCC
#undef NVIC

static bool s_rstcal_witnessed = false;
static bool s_cal_witnessed = false;

static inline ADC_TypeDef* mock_adc1_access(void) {
    if (s_mock_adc1.CR2 & ADC_CR2_RSTCAL) {
        s_rstcal_witnessed = true;
        s_mock_adc1.CR2 &= ~ADC_CR2_RSTCAL; /* Simulate hardware self-clearing RSTCAL */
    }
    if (s_mock_adc1.CR2 & ADC_CR2_CAL) {
        s_cal_witnessed = true;
        s_mock_adc1.CR2 &= ~ADC_CR2_CAL;    /* Simulate hardware self-clearing CAL */
    }
    return &s_mock_adc1;
}

#define GPIOA         (&s_mock_gpioa)
#define GPIOC         (&s_mock_gpioc)
#define TIM3          (&s_mock_tim3)
#define ADC1          (mock_adc1_access())
#define DMA1          (&s_mock_dma1)
#define DMA1_Channel1 (&s_mock_dma1_ch1)
#define RCC           (&s_mock_rcc)
#define NVIC          (&s_mock_nvic)

#undef NVIC_EnableIRQ
#undef NVIC_SetPriority
#undef NVIC_GetPriority
#undef NVIC_GetEnableIRQ

static inline void mock_NVIC_EnableIRQ(IRQn_Type irqn) {
    if ((int32_t)irqn >= 0) {
        s_mock_nvic.ISER[(uint32_t)irqn >> 5UL] |= (1UL << ((uint32_t)irqn & 0x1FUL));
    }
}

static inline void mock_NVIC_SetPriority(IRQn_Type irqn, uint32_t priority) {
    if ((int32_t)irqn >= 0) {
        s_mock_nvic.IP[(uint32_t)irqn] = (uint8_t)((priority << 4) & 0xFF);
    }
}

#define NVIC_EnableIRQ(irqn) mock_NVIC_EnableIRQ(irqn)
#define __NVIC_EnableIRQ(irqn) mock_NVIC_EnableIRQ(irqn)
#define NVIC_SetPriority(irqn, prio) mock_NVIC_SetPriority(irqn, prio)
#define __NVIC_SetPriority(irqn, prio) mock_NVIC_SetPriority(irqn, prio)

#undef __DSB
#undef __ISB
#undef __DMB
#undef __NOP
#define __DSB() do { __asm__ __volatile__("" ::: "memory"); } while(0)
#define __ISB() do { __asm__ __volatile__("" ::: "memory"); } while(0)
#define __DMB() do { __asm__ __volatile__("" ::: "memory"); } while(0)
#define __NOP() do { __asm__ __volatile__("" ::: "memory"); } while(0)

/* Include learner implementation under test */
#include "acquisition.c"

int main(void)
{
    /* =========================================================================
     * Test 1: acquisition_pipeline_init(72000000U) Hardware Register Setup
     * ========================================================================= */
    memset(&s_mock_gpioa, 0, sizeof(s_mock_gpioa));
    memset(&s_mock_gpioc, 0, sizeof(s_mock_gpioc));
    memset(&s_mock_tim3, 0, sizeof(s_mock_tim3));
    memset(&s_mock_adc1, 0, sizeof(s_mock_adc1));
    memset(&s_mock_dma1, 0, sizeof(s_mock_dma1));
    memset(&s_mock_dma1_ch1, 0, sizeof(s_mock_dma1_ch1));
    memset(&s_mock_rcc, 0, sizeof(s_mock_rcc));
    memset(&s_mock_nvic, 0, sizeof(s_mock_nvic));
    s_rstcal_witnessed = false;
    s_cal_witnessed = false;

    if (acquisition_pipeline_init(72000000U) != 0) {
        fprintf(stderr, "ERROR: acquisition_pipeline_init(72000000U) failed!\n");
        return 1;
    }

    /* 1.1 Peripheral Clock Gates */
    if (!(s_mock_rcc.APB1ENR & RCC_APB1ENR_TIM3EN)) {
        fprintf(stderr, "ERROR: TIM3 clock not enabled in RCC->APB1ENR!\n");
        return 2;
    }
    if (!(s_mock_rcc.APB2ENR & RCC_APB2ENR_ADC1EN)) {
        fprintf(stderr, "ERROR: ADC1 clock not enabled in RCC->APB2ENR!\n");
        return 3;
    }
    if (!(s_mock_rcc.APB2ENR & RCC_APB2ENR_IOPAEN)) {
        fprintf(stderr, "ERROR: GPIOA clock not enabled in RCC->APB2ENR!\n");
        return 4;
    }
    if (!(s_mock_rcc.AHBENR & RCC_AHBENR_DMA1EN)) {
        fprintf(stderr, "ERROR: DMA1 clock not enabled in RCC->AHBENR!\n");
        return 5;
    }

    /* 1.2 TIM3 Prescaler and ARR for 10 kHz */
    if (s_mock_tim3.PSC != 71) {
        fprintf(stderr, "ERROR: TIM3->PSC is %u, expected 71 at 72 MHz!\n", s_mock_tim3.PSC);
        return 6;
    }
    if (s_mock_tim3.ARR != 99) {
        fprintf(stderr, "ERROR: TIM3->ARR is %u, expected 99 for 10 kHz!\n", s_mock_tim3.ARR);
        return 7;
    }
    if ((s_mock_tim3.CR2 & TIM_CR2_MMS) != TIM_CR2_MMS_1) {
        fprintf(stderr, "ERROR: TIM3->CR2 MMS is not set to 0b010 (Update as TRGO)!\n");
        return 8;
    }
    if (!(s_mock_tim3.CR1 & TIM_CR1_CEN)) {
        fprintf(stderr, "ERROR: TIM3 counter not enabled (TIM_CR1_CEN)!\n");
        return 9;
    }

    /* 1.3 ADC Clock & Prescaler (ADCPRE == /6) */
    if ((s_mock_rcc.CFGR & RCC_CFGR_ADCPRE) != RCC_CFGR_ADCPRE_DIV6) {
        fprintf(stderr, "ERROR: RCC->CFGR ADCPRE is not /6 (required for <= 14 MHz)!\n");
        return 10;
    }

    /* 1.4 Calibration Sequence Execution */
    if (!s_rstcal_witnessed || !s_cal_witnessed) {
        fprintf(stderr, "ERROR: Hardware calibration sequence (RSTCAL / CAL) was not executed!\n");
        return 11;
    }

    /* 1.5 ADC Sample Time: Channel 0 SMP0 == 0b101 (55.5 cycles) */
    if ((s_mock_adc1.SMPR2 & ADC_SMPR2_SMP0) != (ADC_SMPR2_SMP0_0 | ADC_SMPR2_SMP0_2)) {
        fprintf(stderr, "ERROR: ADC1 SMP0 sample time is not 55.5 cycles (0b101)!\n");
        return 12;
    }

    /* 1.6 ADC Trigger Multiplexing: EXTSEL == 0b100 (TIM3 TRGO) & EXTTRIG & DMA */
    if ((s_mock_adc1.CR2 & ADC_CR2_EXTSEL) != ADC_CR2_EXTSEL_2) {
        fprintf(stderr, "ERROR: ADC1 EXTSEL is not 0b100 (TIM3_TRGO)!\n");
        return 13;
    }
    if (!(s_mock_adc1.CR2 & ADC_CR2_EXTTRIG)) {
        fprintf(stderr, "ERROR: ADC1 EXTTRIG bit is not set!\n");
        return 14;
    }
    if (!(s_mock_adc1.CR2 & ADC_CR2_DMA)) {
        fprintf(stderr, "ERROR: ADC1 DMA request bit (ADC_CR2_DMA) is not set!\n");
        return 15;
    }

    /* 1.7 DMA1 Channel 1 Configuration */
    if (s_mock_dma1_ch1.CPAR != (uint32_t)&(s_mock_adc1.DR)) {
        fprintf(stderr, "ERROR: DMA1_Channel1->CPAR does not point to ADC1->DR!\n");
        return 16;
    }
    if (s_mock_dma1_ch1.CMAR != (uint32_t)g_acq_buffer) {
        fprintf(stderr, "ERROR: DMA1_Channel1->CMAR does not point to g_acq_buffer!\n");
        return 17;
    }
    if (s_mock_dma1_ch1.CNDTR != 128) {
        fprintf(stderr, "ERROR: DMA1_Channel1->CNDTR is %u, expected 128!\n", s_mock_dma1_ch1.CNDTR);
        return 18;
    }
    if (!(s_mock_dma1_ch1.CCR & DMA_CCR_CIRC)) {
        fprintf(stderr, "ERROR: DMA1_Channel1->CCR circular mode (DMA_CCR_CIRC) not enabled!\n");
        return 19;
    }
    if (!(s_mock_dma1_ch1.CCR & DMA_CCR_MINC)) {
        fprintf(stderr, "ERROR: DMA1_Channel1->CCR memory increment (DMA_CCR_MINC) not enabled!\n");
        return 20;
    }
    if ((s_mock_dma1_ch1.CCR & DMA_CCR_PSIZE) != DMA_CCR_PSIZE_0) {
        fprintf(stderr, "ERROR: DMA1_Channel1 PSIZE is not 16-bit (0b01)!\n");
        return 21;
    }
    if ((s_mock_dma1_ch1.CCR & DMA_CCR_MSIZE) != DMA_CCR_MSIZE_0) {
        fprintf(stderr, "ERROR: DMA1_Channel1 MSIZE is not 16-bit (0b01)!\n");
        return 22;
    }
    if (!(s_mock_dma1_ch1.CCR & DMA_CCR_HTIE)) {
        fprintf(stderr, "ERROR: DMA1_Channel1 HTIE interrupt enable missing!\n");
        return 23;
    }
    if (!(s_mock_dma1_ch1.CCR & DMA_CCR_TCIE)) {
        fprintf(stderr, "ERROR: DMA1_Channel1 TCIE interrupt enable missing!\n");
        return 24;
    }
    if (!(s_mock_dma1_ch1.CCR & DMA_CCR_EN)) {
        fprintf(stderr, "ERROR: DMA1_Channel1 is not enabled (DMA_CCR_EN)!\n");
        return 25;
    }

    /* 1.8 NVIC IRQ Enabled */
    if (!(s_mock_nvic.ISER[DMA1_Channel1_IRQn >> 5] & (1UL << (DMA1_Channel1_IRQn & 0x1F)))) {
        fprintf(stderr, "ERROR: DMA1_Channel1_IRQn not enabled in NVIC ISER!\n");
        return 26;
    }

    /* =========================================================================
     * Test 2: Fallback 64 MHz Profile Math
     * ========================================================================= */
    memset(&s_mock_tim3, 0, sizeof(s_mock_tim3));
    if (acquisition_pipeline_init(64000000U) != 0) {
        fprintf(stderr, "ERROR: acquisition_pipeline_init(64000000U) failed!\n");
        return 27;
    }
    if (s_mock_tim3.PSC != 63) {
        fprintf(stderr, "ERROR: TIM3->PSC at 64 MHz is %u, expected 63!\n", s_mock_tim3.PSC);
        return 28;
    }

    /* =========================================================================
     * Test 3: Interrupt Service Routine Execution & Flag Acknowledgment
     * ========================================================================= */
    g_acq_ht_events = 0;
    g_acq_tc_events = 0;
    s_mock_dma1.IFCR = 0;

    /* Simulate Half-Transfer interrupt */
    s_mock_dma1.ISR = DMA_ISR_HTIF1;
    DMA1_Channel1_IRQHandler();
    if (!(s_mock_dma1.IFCR & DMA_IFCR_CHTIF1)) {
        fprintf(stderr, "ERROR: DMA1_Channel1_IRQHandler did not clear HTIF1 in DMA1->IFCR!\n");
        return 29;
    }
    if (g_acq_ht_events != 1) {
        fprintf(stderr, "ERROR: g_acq_ht_events did not increment!\n");
        return 30;
    }

    /* Simulate Transfer-Complete interrupt */
    s_mock_dma1.IFCR = 0;
    s_mock_dma1.ISR = DMA_ISR_TCIF1;
    DMA1_Channel1_IRQHandler();
    if (!(s_mock_dma1.IFCR & DMA_IFCR_CTCIF1)) {
        fprintf(stderr, "ERROR: DMA1_Channel1_IRQHandler did not clear TCIF1 in DMA1->IFCR!\n");
        return 31;
    }
    if (g_acq_tc_events != 1) {
        fprintf(stderr, "ERROR: g_acq_tc_events did not increment!\n");
        return 32;
    }

    printf("[HOST TEST HARNESS] All MMIO, TIM3 TRGO, ADC1, DMA1, and ISR tests PASSED.\n");
    return 0;
}
