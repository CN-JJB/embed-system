/**
 * test_harness_host.c: Host-side unit test harness for learner PWM logic
 */
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#define STM32F103xB
#include "stm32f103xb.h"

static GPIO_TypeDef s_mock_gpioa;
static TIM_TypeDef  s_mock_tim2;
static RCC_TypeDef  s_mock_rcc;
static NVIC_Type    s_mock_nvic;

#undef GPIOA
#undef TIM2
#undef RCC
#undef NVIC

#define GPIOA (&s_mock_gpioa)
#define TIM2  (&s_mock_tim2)
#define RCC   (&s_mock_rcc)
#define NVIC  (&s_mock_nvic)

/* Include learner implementation */
#include "pwm.c"

int main(void)
{
    memset(&s_mock_gpioa, 0, sizeof(s_mock_gpioa));
    memset(&s_mock_tim2, 0, sizeof(s_mock_tim2));
    memset(&s_mock_rcc, 0, sizeof(s_mock_rcc));
    memset(&s_mock_nvic, 0, sizeof(s_mock_nvic));

    /* Test 1: Channel bounds */
    for (uint8_t ch = 0; ch < 4; ch++) {
        if (!pwm_set_duty(ch, 50)) {
            fprintf(stderr, "ERROR: pwm_set_duty rejected valid channel %u\n", ch);
            return 1;
        }
    }
    if (pwm_set_duty(4, 50)) {
        fprintf(stderr, "ERROR: pwm_set_duty accepted invalid channel 4\n");
        return 2;
    }
    if (pwm_set_duty(5, 50)) {
        fprintf(stderr, "ERROR: pwm_set_duty accepted invalid channel 5\n");
        return 3;
    }

    /* Test 2: Duty percentage bounds */
    if (!pwm_set_duty(0, 0) || !pwm_set_duty(0, 1) || !pwm_set_duty(0, 100)) {
        fprintf(stderr, "ERROR: pwm_set_duty rejected valid boundary duty values (0, 1, 100)\n");
        return 4;
    }
    if (pwm_set_duty(0, 101)) {
        fprintf(stderr, "ERROR: pwm_set_duty accepted out-of-bounds duty 101\n");
        return 5;
    }
    if (pwm_set_duty(0, 200)) {
        fprintf(stderr, "ERROR: pwm_set_duty accepted out-of-bounds duty 200\n");
        return 6;
    }

    /* Test 3: 100-step wrap and output assertion */
    pwm_set_duty(0, 25);
    for (int i = 0; i < 200; i++) {
        uint8_t expected_step = (uint8_t)(i % 100);
        uint8_t actual_step = pwm_step();
        if (actual_step != expected_step) {
            fprintf(stderr, "ERROR: Step wrap failed at iteration %d! Expected %u, got %u\n",
                    i, expected_step, actual_step);
            return 7;
        }
    }

    /* Test 4: Verify GPIOA writes use BSRR / BRR, never ODR */
    if (s_mock_gpioa.ODR != 0) {
        fprintf(stderr, "ERROR: GPIOA->ODR was modified directly! Non-atomic RMW detected.\n");
        return 8;
    }
    if (s_mock_gpioa.BSRR == 0 && s_mock_gpioa.BRR == 0) {
        fprintf(stderr, "ERROR: No atomic writes to BSRR or BRR occurred during pwm_step!\n");
        return 9;
    }

    printf("ALL_HOST_PWM_TESTS_PASSED\n");
    return 0;
}
