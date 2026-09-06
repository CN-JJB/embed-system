#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>

/**
 * @brief Initialize TIM3 as a 1.0 kHz periodic master trigger generator (TRGO on Update).
 * @param tim_clock_hz Input clock frequency to TIM3 (72 MHz under canonical profile).
 */
void tim3_trgo_init_1khz(uint32_t tim_clock_hz);

#endif /* TIMER_H */
