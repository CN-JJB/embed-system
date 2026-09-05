#ifndef EMB_MCU_02_PWM_H
#define EMB_MCU_02_PWM_H

#include <stdint.h>
#include <stdbool.h>

#define PWM_NUM_CHANNELS 4
#define PWM_STEPS        100
#define PWM_TICK_HZ      10000U
#define PWM_BASE_HZ      100U

bool pwm_init(uint32_t timclk_hz);
bool pwm_set_duty(uint8_t channel, uint8_t duty_percent);
uint8_t pwm_get_duty(uint8_t channel);
uint8_t pwm_step(void);
void TIM2_IRQHandler(void);

#endif /* EMB_MCU_02_PWM_H */
