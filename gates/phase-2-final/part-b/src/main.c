/**
 * =============================================================================
 * P2-M03 Main Application: Autonomous ADC + DMA Circular Acquisition
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M03 Peripheral Acquisition, ADC Sampling Contract, and DMA Data Path
 *
 * Hardware Trigger & Transfer Chain:
 *   TIM3 Update @ 10 kHz
 *     ──► TIM3 TRGO (MMS = 010)
 *     ──► ADC1 Regular Trigger (EXTSEL = 100, EXTTRIG = 1)
 *     ──► ADC1 Conversion (PA0, 55.5 cycles sample time, 12 MHz ADCCLK)
 *     ──► ADC1 DMA Request
 *     ──► DMA1 Channel 1
 *     ──► Circular Buffer in SRAM (uint16_t g_adc_buffer[2][64])
 *     ──► Half-Transfer (HT) ISR -> pulse PA3
 *     ──► Transfer-Complete (TC) ISR -> pulse PA4
 *
 * Notice: CPU enters low-power sleep via __WFI(); data acquisition is
 * entirely hardware-autonomous!
 * =============================================================================
 */

#include "clock.h"
#include "gpio.h"
#include "adc.h"
#include "timer.h"
#include "dma.h"
#include "stm32f103xb.h"
#include "core_cm3.h"

int main(void)
{
    /* 1. Initialize clock tree: try 72 MHz HSE primary, fall back to 64 MHz HSI */
    clock_frequencies_t freqs;
    if (!clock_init(CLOCK_PROFILE_72MHZ_HSE)) {
        if (!clock_init(CLOCK_PROFILE_64MHZ_HSI)) {
            /* Clock failure: trap in infinite loop */
            while (1) {
                __NOP();
            }
        }
    }
    clock_get_frequencies(&freqs);

    /* 2. Configure GPIO pins (PA0 analog input, PA3/PA4 marker outputs, PC13 LED) */
    gpio_init();

    /* 3. Configure DMA1 Channel 1 for circular double-buffering */
    dma1_channel1_init();

    /* 4. Configure ADC1 (ADCPRE=/6, PA0 sample time 55.5 cycles, calibration, TIM3 TRGO trigger) */
    int adc_status = adc_init(freqs.pclk2_hz);
    if (adc_status != ADC_INIT_OK) {
        /* Calibration failure: trap with LED error indication */
        while (1) {
            GPIOC->ODR ^= GPIO_ODR_ODR13;
            for (volatile uint32_t i = 0; i < 500000; i++) {
                __NOP();
            }
        }
    }

    /* 5. Start TIM3 TRGO trigger at 10 kHz (launches autonomous conversions) */
    tim3_trgo_init_10khz(freqs.timclk1_hz);

    /* Turn on PC13 User LED to indicate normal acquisition streaming */
    GPIOC->BRR = GPIO_BRR_BR13;

    /*
     * 6. CPU autonomous wait loop:
     *    The CPU has zero active responsibilities in the acquisition data path!
     *    DMA moves converted samples across the AHB bus directly into SRAM.
     *    CPU wakes only briefly to service DMA HT/TC interrupts and sleep again.
     */
    while (1) {
        __WFI();
    }

    return 0;
}
