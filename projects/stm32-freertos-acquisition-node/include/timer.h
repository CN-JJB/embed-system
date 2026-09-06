#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>

/**
 * @brief Configure TIM3 as a 1.0 kHz periodic master trigger generator (TRGO on Update).
 * Does not start counter until tim3_trgo_start() is explicitly called.
 * @param tim_clock_hz Input clock frequency to TIM3 (72 MHz HSE or 64 MHz HSI fallback).
 */
void tim3_trgo_init_1khz(uint32_t tim_clock_hz);

/**
 * @brief Start TIM3 counter to begin hardware TRGO pulse generation.
 */
void tim3_trgo_start(void);

/**
 * @brief Stop TIM3 counter.
 */
void tim3_trgo_stop(void);

#endif /* TIMER_H */
