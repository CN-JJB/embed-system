#ifndef USART_H
#define USART_H

#include <stdint.h>
#include <stdbool.h>

/**
 * @brief Initialize USART1 at 115200 baud, 8N1, using direct CMSIS register access.
 * @param pclk2_hz APB2 peripheral clock frequency in Hz (72 MHz canonical).
 */
void usart1_init(uint32_t pclk2_hz);

/**
 * @brief Write a single byte to USART1 via polling TXE status bit.
 */
void usart1_write_byte(uint8_t ch);

/**
 * @brief Write a null-terminated string to USART1.
 */
void usart1_write_str(const char *str);

/**
 * @brief Write an unsigned 32-bit integer formatted as decimal text to USART1.
 */
void usart1_write_u32(uint32_t val);

#endif /* USART_H */
