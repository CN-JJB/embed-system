/**
 * =============================================================================
 * Direct Register USART1 Driver for STM32F103C8T6
 * =============================================================================
 * Course: Embedded Systems Foundations - Phase 2 MCU & FreeRTOS
 * Project: P2-M07 STM32 FreeRTOS Acquisition Node Integration Project
 * =============================================================================
 */

#include "usart.h"
#include "stm32f103xb.h"

void usart1_init(uint32_t pclk2_hz)
{
    /* 1. Enable APB2 clock gates for USART1 and GPIOA */
    RCC->APB2ENR |= RCC_APB2ENR_USART1EN | RCC_APB2ENR_IOPAEN;

    /*
     * 2. Configure GPIO Pins for USART1:
     *    - PA9:  TX, Alternate function output Push-Pull, 50 MHz (MODE9 = 11, CNF9 = 10)
     *    - PA10: RX, Input floating (MODE10 = 00, CNF10 = 01)
     */
    GPIOA->CRH &= ~(GPIO_CRH_MODE9 | GPIO_CRH_CNF9 | GPIO_CRH_MODE10 | GPIO_CRH_CNF10);
    GPIOA->CRH |= (GPIO_CRH_MODE9_0 | GPIO_CRH_MODE9_1 | GPIO_CRH_CNF9_1);
    GPIOA->CRH |= GPIO_CRH_CNF10_0;

    /*
     * 3. Configure Baud Rate:
     *    USARTDIV is represented in BRR with 4 fractional bits (i.e. USARTDIV * 16).
     *    Since USARTDIV = pclk2_hz / (16 * baud), USARTDIV * 16 = pclk2_hz / baud.
     *    With rounding to nearest 1/16th:
     *      BRR = (pclk2_hz + (baud / 2)) / baud
     *    Under 72 MHz: BRR = (72000000 + 57600) / 115200 = 625 = 0x0271
     *    Under 64 MHz: BRR = (64000000 + 57600) / 115200 = 556 = 0x022C
     */
    uint32_t baud = 115200U;
    USART1->BRR = (72000000U + (baud / 2U)) / baud;


    /* 4. Enable Transmitter and USART peripheral (8 data bits, no parity, 1 stop bit) */
    USART1->CR1 = USART_CR1_UE | USART_CR1_TE;
}

void usart1_write_byte(uint8_t ch)
{
    /* Wait until transmit data register is empty (TXE status bit set) */
    while (!(USART1->SR & USART_SR_TXE)) {
        __NOP();
    }
    USART1->DR = (ch & 0xFFU);
}

void usart1_write_str(const char *str)
{
    if (!str) return;
    while (*str) {
        usart1_write_byte((uint8_t)*str++);
    }
}

void usart1_write_u32(uint32_t val)
{
    char buf[11];
    int idx = 0;

    if (val == 0) {
        usart1_write_byte('0');
        return;
    }

    while (val > 0) {
        buf[idx++] = (char)('0' + (val % 10));
        val /= 10;
    }

    while (idx > 0) {
        usart1_write_byte((uint8_t)buf[--idx]);
    }
}
