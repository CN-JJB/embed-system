#ifndef GPIO_H
#define GPIO_H

#include <stdint.h>
#include "stm32f103xb.h"

/**
 * @brief Initialize GPIO pins for task markers and diagnostics.
 *
 * Configures:
 *  - PA1: General purpose output push-pull 50 MHz (ISR marker)
 *  - PA2: General purpose output push-pull 50 MHz (Consumer Task marker)
 *  - PC13: General purpose output push-pull 2 MHz (User LED)
 */
void gpio_init(void);

static inline void gpio_set_pa1(void)   { GPIOA->BSRR = (1U << 1); }
static inline void gpio_clear_pa1(void) { GPIOA->BRR  = (1U << 1); }
static inline void gpio_toggle_pa1(void)
{
    if ((GPIOA->ODR & (1U << 1)) != 0) {
        GPIOA->BRR = (1U << 1);
    } else {
        GPIOA->BSRR = (1U << 1);
    }
}

static inline void gpio_set_pa2(void)   { GPIOA->BSRR = (1U << 2); }
static inline void gpio_clear_pa2(void) { GPIOA->BRR  = (1U << 2); }
static inline void gpio_toggle_pa2(void)
{
    if ((GPIOA->ODR & (1U << 2)) != 0) {
        GPIOA->BRR = (1U << 2);
    } else {
        GPIOA->BSRR = (1U << 2);
    }
}

static inline void gpio_toggle_led(void)
{
    if ((GPIOC->ODR & GPIO_ODR_ODR13) != 0) {
        GPIOC->BRR = GPIO_BRR_BR13;
    } else {
        GPIOC->BSRR = GPIO_BSRR_BS13;
    }
}

#endif /* GPIO_H */
