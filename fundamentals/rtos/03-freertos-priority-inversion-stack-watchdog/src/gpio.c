/**
 * =============================================================================
 * GPIO Configuration Implementation for STM32F103C8T6
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M04 FreeRTOS Scheduler, Task Lifecycle, and Context Switch
 * =============================================================================
 */

#include "gpio.h"
#include "stm32f103xb.h"

void gpio_init(void)
{
    /* Enable GPIOA and GPIOC peripheral clocks */
    RCC->APB2ENR |= RCC_APB2ENR_IOPAEN | RCC_APB2ENR_IOPCEN;

    /*
     * Configure PA1 as General Purpose Output Push-Pull 50 MHz (Task_A marker):
     *   MODE1 = 11 (Output 50 MHz), CNF1 = 00 (Push-pull)
     */
    GPIOA->CRL &= ~(GPIO_CRL_MODE1 | GPIO_CRL_CNF1);
    GPIOA->CRL |= (GPIO_CRL_MODE1_0 | GPIO_CRL_MODE1_1);

    /*
     * Configure PA2 as General Purpose Output Push-Pull 50 MHz (Task_B marker):
     *   MODE2 = 11 (Output 50 MHz), CNF2 = 00 (Push-pull)
     */
    GPIOA->CRL &= ~(GPIO_CRL_MODE2 | GPIO_CRL_CNF2);
    GPIOA->CRL |= (GPIO_CRL_MODE2_0 | GPIO_CRL_MODE2_1);

    /* Initial state: PA1 LOW, PA2 LOW */
    GPIOA->BRR = (1 << 1) | (1 << 2);

    /*
     * Configure PC13 as Output Push-Pull 2 MHz (User LED):
     *   MODE13 = 10 (Output 2 MHz), CNF13 = 00 (Push-pull)
     */
    GPIOC->CRH &= ~(GPIO_CRH_MODE13 | GPIO_CRH_CNF13);
    GPIOC->CRH |= GPIO_CRH_MODE13_1;

    /* Turn off LED initially (Active LOW) */
    GPIOC->BSRR = GPIO_BSRR_BS13;
}
