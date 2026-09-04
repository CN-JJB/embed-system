/**
 * =============================================================================
 * Clock Tree Configuration Header for STM32F103C8T6
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M02 MMIO, Clock Tree, Hardware Timers, and NVIC Mechanism
 *
 * Direct-register clock configuration supporting:
 *   - Primary Profile: 72 MHz SYSCLK via 8 MHz HSE crystal
 *   - Fallback Profile: 64 MHz SYSCLK via 8 MHz internal HSI oscillator
 * =============================================================================
 */

#ifndef CLOCK_H
#define CLOCK_H

#include <stdint.h>
#include <stdbool.h>

typedef enum {
    CLOCK_PROFILE_72MHZ_HSE = 0,
    CLOCK_PROFILE_64MHZ_HSI = 1
} clock_profile_t;

typedef struct {
    uint32_t sysclk_hz;     /* System clock (SYSCLK) in Hz */
    uint32_t hclk_hz;       /* AHB bus clock (HCLK) in Hz */
    uint32_t pclk1_hz;      /* APB1 peripheral bus clock (PCLK1) in Hz (max 36 MHz) */
    uint32_t pclk2_hz;      /* APB2 peripheral bus clock (PCLK2) in Hz (max 72 MHz) */
    uint32_t timclk1_hz;    /* APB1 timer input clock in Hz (subject to x2 rule) */
    uint32_t timclk2_hz;    /* APB2 timer input clock in Hz */
} clock_frequencies_t;

/**
 * @brief Initialize system clock using the specified profile.
 * Configures Flash latency wait states, prefetch buffer, PLL, and bus dividers.
 * @param profile Target clock profile.
 * @return true if clock locked successfully, false if oscillator timed out.
 */
bool clock_init(clock_profile_t profile);

/**
 * @brief Retrieve currently active clock frequencies.
 * Calculates exact frequencies directly from live RCC register state.
 */
void clock_get_frequencies(clock_frequencies_t *freqs);

#endif /* CLOCK_H */
