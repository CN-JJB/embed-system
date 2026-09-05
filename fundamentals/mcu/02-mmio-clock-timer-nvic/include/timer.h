/**
 * =============================================================================
 * Hardware Timer (TIM2) Direct Register Configuration Header
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M02 MMIO, Clock Tree, Hardware Timers, and NVIC Mechanism
 * =============================================================================
 */

#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>
#include <stdbool.h>

/**
 * @brief Initialize TIM2 for periodic 1.0 ms (1 kHz) update interrupts.
 *
 * Direct Register Configuration:
 *   - Enables TIM2 peripheral clock in RCC->APB1ENR
 *   - Derives PSC and ARR from timer input clock (timclk1)
 *   - Enables update interrupt in TIM2->DIER
 *   - Configures NVIC priority (logical 6, encoded 0x60)
 *   - Enables TIM2 IRQ line in NVIC
 *   - Starts counter (TIM2->CR1 CEN)
 *
 * @param timclk_hz Timer input clock frequency in Hz.
 */
void tim2_init_1khz(uint32_t timclk_hz);

/**
 * @brief Global tick counter incremented by TIM2_IRQHandler.
 * Marked volatile to inform compiler that value changes asynchronously in ISR.
 */
extern volatile uint32_t g_tim2_ticks;

#endif /* TIMER_H */
