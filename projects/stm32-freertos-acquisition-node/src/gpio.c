/**
 * =============================================================================
 * Direct Register GPIO Implementation for STM32F103C8T6
 * =============================================================================
 * Course: Embedded Systems Foundations - Phase 2 MCU & FreeRTOS
 * Project: P2-M07 STM32 FreeRTOS Acquisition Node Integration Project
 * =============================================================================
 */

#include "gpio.h"
#include "stm32f103xb.h"

void gpio_init(void)
{
    /* Enable GPIOA and GPIOC clock gates on APB2 */
    RCC->APB2ENR |= RCC_APB2ENR_IOPAEN | RCC_APB2ENR_IOPCEN;

    /*
     * PA0: Analog input (ADC1 Channel 0)
     * MODE0 = 00 (Input), CNF0 = 00 (Analog)
     */
    GPIOA->CRL &= ~(GPIO_CRL_MODE0 | GPIO_CRL_CNF0);

    /*
     * PA1..PA4: General purpose output push-pull, 50 MHz (MODE = 11, CNF = 00)
     * PA1: Event / Task_Process marker
     * PA2: Task_Compute active marker
     * PA3: Task_Health active marker
     * PA4: Diagnostic resource held marker
     */
    GPIOA->CRL &= ~(GPIO_CRL_MODE1 | GPIO_CRL_CNF1 |
                    GPIO_CRL_MODE2 | GPIO_CRL_CNF2 |
                    GPIO_CRL_MODE3 | GPIO_CRL_CNF3 |
                    GPIO_CRL_MODE4 | GPIO_CRL_CNF4);

    GPIOA->CRL |= (GPIO_CRL_MODE1_0 | GPIO_CRL_MODE1_1) |
                  (GPIO_CRL_MODE2_0 | GPIO_CRL_MODE2_1) |
                  (GPIO_CRL_MODE3_0 | GPIO_CRL_MODE3_1) |
                  (GPIO_CRL_MODE4_0 | GPIO_CRL_MODE4_1);

    /* Clear PA1..PA4 initially */
    GPIOA->BRR = (GPIO_BRR_BR1 | GPIO_BRR_BR2 | GPIO_BRR_BR3 | GPIO_BRR_BR4);

    /*
     * PC13: User LED on Blue Pill (Active LOW)
     * Output push-pull, 2 MHz (MODE = 10, CNF = 00)
     */
    GPIOC->CRH &= ~(GPIO_CRH_MODE13 | GPIO_CRH_CNF13);
    GPIOC->CRH |= GPIO_CRH_MODE13_1;

    /* Turn off LED initially (HIGH) */
    GPIOC->BSRR = GPIO_BSRR_BS13;
}

void gpio_set_pa1(void)
{
    GPIOA->BSRR = GPIO_BSRR_BS1;
}

void gpio_clear_pa1(void)
{
    GPIOA->BRR = GPIO_BRR_BR1;
}

void gpio_toggle_pa1(void)
{
    if (GPIOA->ODR & GPIO_ODR_ODR1) {
        GPIOA->BRR = GPIO_BRR_BR1;
    } else {
        GPIOA->BSRR = GPIO_BSRR_BS1;
    }
}

void gpio_set_pa2(void)
{
    GPIOA->BSRR = GPIO_BSRR_BS2;
}

void gpio_clear_pa2(void)
{
    GPIOA->BRR = GPIO_BRR_BR2;
}

void gpio_set_pa3(void)
{
    GPIOA->BSRR = GPIO_BSRR_BS3;
}

void gpio_clear_pa3(void)
{
    GPIOA->BRR = GPIO_BRR_BR3;
}

void gpio_set_pa4(void)
{
    GPIOA->BSRR = GPIO_BSRR_BS4;
}

void gpio_clear_pa4(void)
{
    GPIOA->BRR = GPIO_BRR_BR4;
}

void gpio_set_led(void)
{
    GPIOC->BRR = GPIO_BRR_BR13; /* Active LOW -> Turn ON */
}

void gpio_clear_led(void)
{
    GPIOC->BSRR = GPIO_BSRR_BS13; /* Turn OFF */
}

void gpio_toggle_led(void)
{
    if (GPIOC->ODR & GPIO_ODR_ODR13) {
        GPIOC->BRR = GPIO_BRR_BR13;
    } else {
        GPIOC->BSRR = GPIO_BSRR_BS13;
    }
}
