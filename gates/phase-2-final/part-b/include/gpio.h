#ifndef GPIO_H
#define GPIO_H

#include <stdint.h>

/**
 * @brief Initialize GPIO ports for acquisition and debug markers.
 *
 * Configures:
 *  - PA0: Analog Input (ADC1 Channel 0).
 *  - PA3: Output Push-Pull 50 MHz (Half-Transfer HT marker pulse).
 *  - PA4: Output Push-Pull 50 MHz (Transfer-Complete TC marker pulse).
 *  - PC13: Output Push-Pull 2 MHz (Board User LED).
 */
void gpio_init(void);

#endif /* GPIO_H */
