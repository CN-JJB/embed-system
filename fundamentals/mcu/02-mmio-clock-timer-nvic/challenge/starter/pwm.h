#ifndef CHALLENGE_PWM_H
#define CHALLENGE_PWM_H

#include <stdint.h>
#include <stdbool.h>

#define PWM_NUM_CHANNELS 4

/**
 * @brief Initialize TIM2 and GPIOA (PA0-PA3) for 4-channel 100 Hz PWM (10 kHz tick).
 */
bool pwm_init(uint32_t timclk_hz);

/**
 * @brief Set duty cycle for a PWM channel (0% to 100%).
 */
bool pwm_set_duty(uint8_t channel, uint8_t duty_percent);

#endif /* CHALLENGE_PWM_H */
