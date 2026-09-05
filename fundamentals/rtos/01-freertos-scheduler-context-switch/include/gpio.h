#ifndef GPIO_H
#define GPIO_H

#include <stdint.h>

/**
 * @brief Initialize GPIO pins for task markers and diagnostics.
 *
 * Configures:
 *  - PA1: General purpose output push-pull 50 MHz (Task_A marker)
 *  - PA2: General purpose output push-pull 50 MHz (Task_B marker)
 *  - PC13: General purpose output push-pull 2 MHz (User LED)
 */
void gpio_init(void);

#endif /* GPIO_H */
