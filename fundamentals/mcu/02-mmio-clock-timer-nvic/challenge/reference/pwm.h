#ifndef CHALLENGE_PWM_H
#define CHALLENGE_PWM_H

#include <stdint.h>
#include <stdbool.h>

#define PWM_NUM_CHANNELS 4

/**
 * @brief Initialize TIM2 and GPIOA (PA0-PA3) for 4-channel 100 Hz PWM with 10 kHz tick.
 * @param timclk_hz Timer input clock frequency (e.g. 72000000 Hz).
 * @return true on success.
 */
bool pwm_init(uint32_t timclk_hz);

/**
 * @brief Set channel duty cycle from 0% to 100%.
 * @param channel Channel index 0..3 (mapping to PA0..PA3).
 * @param duty_percent Duty cycle percentage 0..100.
 * @return true if parameters are valid.
 */
bool pwm_set_duty(uint8_t channel, uint8_t duty_percent);

#endif /* CHALLENGE_PWM_H */
