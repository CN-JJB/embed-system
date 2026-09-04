/**
 * =============================================================================
 * GPIO and RMW Hazard Demonstration Header
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M02 MMIO, Clock Tree, Hardware Timers, and NVIC Mechanism
 * =============================================================================
 */

#ifndef GPIO_H
#define GPIO_H

#include <stdint.h>

/**
 * @brief Initialize GPIO test pins:
 *   - PA1: Output Push-Pull (Timer 2 ISR timing marker)
 *   - PA2: Output Push-Pull (Main loop non-atomic RMW marker)
 *   - PC13: Output Push-Pull (User LED)
 */
void gpio_init(void);

/**
 * @brief Toggle PA1 using atomic hardware register writes (BSRR / BRR).
 * Hardware write is atomic (single store without reading ODR), protecting
 * concurrent pin states on Port A. Software state tracking is single-context.
 */
void gpio_toggle_pa1_atomic(void);

/**
 * @brief Non-atomic Read-Modify-Write operation on GPIOA->ODR pin 2.
 * Compiles to LDR, ORR/EOR, STR. Vulnerable to preemption hazards!
 */
void gpio_toggle_pa2_non_atomic_rmw(void);

/**
 * @brief Toggle PA2 using atomic hardware register writes (BSRR / BRR).
 */
void gpio_toggle_pa2_atomic(void);

#endif /* GPIO_H */
