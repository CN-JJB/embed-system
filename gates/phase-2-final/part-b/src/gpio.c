/**
 * =============================================================================
 * GPIO Configuration Implementation for STM32F103C8T6
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M03 Peripheral Acquisition, ADC Sampling Contract, and DMA Data Path
 * =============================================================================
 */

#include "gpio.h"
#include "stm32f103xb.h"

void gpio_init(void)
{
    /* Enable GPIOA and GPIOC peripheral clocks */
    RCC->APB2ENR |= RCC_APB2ENR_IOPAEN | RCC_APB2ENR_IOPCEN;

    /*
     * Configure PA0 as Analog Input (ADC1 Channel 0):
     *   MODE0[1:0] = 00 (Input mode)
     *   CNF0[1:0]  = 00 (Analog mode)
     */
    GPIOA->CRL &= ~(GPIO_CRL_MODE0 | GPIO_CRL_CNF0);

    /*
     * Configure PA3 as General Purpose Output Push-Pull 50 MHz (HT marker):
     *   MODE3[1:0] = 11 (Output mode, max speed 50 MHz)
     *   CNF3[1:0]  = 00 (General purpose output push-pull)
     */
    GPIOA->CRL &= ~(GPIO_CRL_MODE3 | GPIO_CRL_CNF3);
    GPIOA->CRL |= (GPIO_CRL_MODE3_0 | GPIO_CRL_MODE3_1);

    /*
     * Configure PA4 as General Purpose Output Push-Pull 50 MHz (TC marker):
     *   MODE4[1:0] = 11 (Output mode, max speed 50 MHz)
     *   CNF4[1:0]  = 00 (General purpose output push-pull)
     */
    GPIOA->CRL &= ~(GPIO_CRL_MODE4 | GPIO_CRL_CNF4);
    GPIOA->CRL |= (GPIO_CRL_MODE4_0 | GPIO_CRL_MODE4_1);

    /* Clear PA3 and PA4 initially via BRR */
    GPIOA->BRR = (1 << 3) | (1 << 4);

    /*
     * Configure PC13 as Output Push-Pull 2 MHz (User LED):
     *   MODE13[1:0] = 10 (Output mode, max speed 2 MHz)
     *   CNF13[1:0]  = 00 (General purpose output push-pull)
     */
    GPIOC->CRH &= ~(GPIO_CRH_MODE13 | GPIO_CRH_CNF13);
    GPIOC->CRH |= GPIO_CRH_MODE13_1;

    /* Turn off PC13 LED (Active LOW on Blue Pill) */
    GPIOC->BSRR = GPIO_BSRR_BS13;
}
