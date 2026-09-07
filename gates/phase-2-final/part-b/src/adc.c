/**
 * =============================================================================
 * ADC1 Direct Register Configuration Implementation for STM32F103C8T6
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M03 Peripheral Acquisition, ADC Sampling Contract, and DMA Data Path
 * =============================================================================
 */

#include "adc.h"
#include "stm32f103xb.h"

#define ADC_STABILIZATION_LOOPS 1000U
#define ADC_CAL_TIMEOUT         100000U

int adc_init(uint32_t pclk2_hz)
{
    /* 1. Enable APB2 clock gate for ADC1 and GPIOA */
    RCC->APB2ENR |= RCC_APB2ENR_ADC1EN | RCC_APB2ENR_IOPAEN;

    /*
     * 2. Configure ADC Prescaler (ADCPRE):
     *    Ceiling requirement: f_ADCCLK <= 14 MHz (RM0008, DS5319).
     *    72 MHz PCLK2 / 6 = 12 MHz <= 14 MHz.
     *    64 MHz PCLK2 / 6 = 10.67 MHz <= 14 MHz.
     */
    RCC->CFGR &= ~RCC_CFGR_ADCPRE;
    RCC->CFGR |= RCC_CFGR_ADCPRE_DIV6;

    (void)pclk2_hz; /* Verified that DIV6 preserves <= 14 MHz for both 72 MHz and 64 MHz */

    /*
     * 3. Configure PA0 as Analog Input (ADC1 Channel 0):
     *    CRL MODE0 = 00 (Input), CNF0 = 00 (Analog)
     */
    GPIOA->CRL &= ~(GPIO_CRL_MODE0 | GPIO_CRL_CNF0);

    /*
     * 4. Configure Sample Time:
     *    SMP0[2:0] = 0b101 (55.5 cycles).
     *    At 12 MHz ADCCLK, Tconv = 55.5 + 12.5 = 68 cycles (~5.67 us).
     *    Conservative lab setting accommodating source impedance up to ~50 kOhm.
     */
    ADC1->SMPR2 &= ~ADC_SMPR2_SMP0;
    ADC1->SMPR2 |= (ADC_SMPR2_SMP0_0 | ADC_SMPR2_SMP0_2);

    /*
     * 5. Configure Regular Sequence:
     *    Sequence length = 1 conversion (SQR1 L[3:0] = 0000).
     *    First conversion = Channel 0 (SQR3 SQ1[4:0] = 00000).
     */
    ADC1->SQR1 &= ~ADC_SQR1_L;
    ADC1->SQR3 &= ~ADC_SQR3_SQ1;

    /*
     * 6. Power on ADC1 and execute hardware calibration sequence (RM0008 Section 11.4):
     *    Step a: Set ADON to wake ADC from power-down mode.
     */
    ADC1->CR2 |= ADC_CR2_ADON;

    /* Step b: Wait stabilization time (t_STAB ~ 1 us) */
    for (volatile uint32_t i = 0; i < ADC_STABILIZATION_LOOPS; i++) {
        __NOP();
    }

    /* Step c: Reset calibration registers */
    ADC1->CR2 |= ADC_CR2_RSTCAL;
    uint32_t timeout = ADC_CAL_TIMEOUT;
    while ((ADC1->CR2 & ADC_CR2_RSTCAL) != 0) {
        if (--timeout == 0) {
            return ADC_INIT_ERR_RSTCAL_TIMEOUT;
        }
    }

    /* Step d: Start calibration and wait for completion */
    ADC1->CR2 |= ADC_CR2_CAL;
    timeout = ADC_CAL_TIMEOUT;
    while ((ADC1->CR2 & ADC_CR2_CAL) != 0) {
        if (--timeout == 0) {
            return ADC_INIT_ERR_CAL_TIMEOUT;
        }
    }

    /*
     * 7. Configure External Trigger and DMA Mode:
     *    - EXTSEL[2:0] = 0b100 (TIM3_TRGO event triggers regular conversion)
     *    - EXTTRIG = 1 (Enable external trigger for regular channels)
     *    - DMA = 1 (Enable ADC DMA request generation)
     */
    ADC1->CR2 &= ~ADC_CR2_EXTSEL;
    ADC1->CR2 |= ADC_CR2_EXTSEL_2;  /* 0b100: TIM3 TRGO */
    ADC1->CR2 |= ADC_CR2_EXTTRIG;
    ADC1->CR2 |= ADC_CR2_DMA;

    return ADC_INIT_OK;
}

uint32_t adc_get_clock_hz(uint32_t pclk2_hz)
{
    static const uint8_t adc_div_table[4] = { 2, 4, 6, 8 };
    uint32_t adcpre = (RCC->CFGR & RCC_CFGR_ADCPRE) >> 14;
    return pclk2_hz / adc_div_table[adcpre];
}
