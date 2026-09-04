#ifndef CHALLENGE_PWM_H
#define CHALLENGE_PWM_H

#include <stdint.h>
#include <stdbool.h>

#define PWM_NUM_CHANNELS 4
#define PWM_STEPS        100
#define PWM_TICK_HZ      10000U
#define PWM_BASE_HZ      100U

/**
 * @brief Initialize TIM2 and GPIOA (PA0-PA3) for 4-channel 100 Hz PWM with 10 kHz tick.
 * Under 72 MHz clock, configures prescaler and auto-reload to yield 10 kHz update event rate.
 * @param timclk_hz Timer input clock frequency (e.g. 72000000 Hz).
 * @return true on success, false on invalid parameter.
 */
bool pwm_init(uint32_t timclk_hz);

/**
 * @brief Set channel duty cycle (0% to 100%).
 * @param channel Channel index (strictly 0 .. PWM_NUM_CHANNELS - 1).
 * @param duty_percent Duty cycle percentage (strictly 0 .. PWM_STEPS).
 * @return true if valid; false if channel >= 4 or duty_percent > 100.
 */
bool pwm_set_duty(uint8_t channel, uint8_t duty_percent);

/**
 * @brief Retrieve configured duty cycle for a channel.
 * @param channel Channel index 0..3.
 * @return duty cycle percentage, or 0xFF if channel is invalid.
 */
uint8_t pwm_get_duty(uint8_t channel);

/**
 * @brief Execute a single PWM step iteration (0..99).
 * Advances the step counter modulo 100 and updates PA0..PA3 via atomic BSRR/BRR writes.
 * @return current step index before increment (0..99).
 */
uint8_t pwm_step(void);

#endif /* CHALLENGE_PWM_H */
