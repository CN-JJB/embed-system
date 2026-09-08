#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>

/**
 * @brief Initialize TIM3 as a master trigger generating TRGO update pulses at 10 kHz.
 *
 * Configures:
 *  - RCC APB1 clock gate for TIM3.
 *  - PSC and ARR derived from active timer clock to produce exactly 10,000 updates/sec.
 *  - Master Mode Selection: MMS = 0b010 (Update event output as TRGO).
 *  - Counter enable (CEN = 1).
 *
 * @param tim_clock_hz Input timer clock frequency in Hz (72 MHz or 64 MHz).
 */
void tim3_trgo_init_10khz(uint32_t tim_clock_hz);

#endif /* TIMER_H */
