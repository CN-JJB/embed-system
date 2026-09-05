/**
 * test_harness_host.c: Host-side unit test harness for learner PWM logic
 * Verifies direct-register MMIO hardware configuration, 4-channel duty semantics,
 * 100-step wrap, atomic BSRR/BRR masking, and TIM2_IRQHandler execution.
 */
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#define STM32F103xB
#include "stm32f103xb.h"
#include "core_cm3.h"

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

#undef NVIC_EnableIRQ
#undef NVIC_SetPriority
#undef NVIC_GetPriority
#undef NVIC_GetEnableIRQ

static inline void mock_NVIC_EnableIRQ(IRQn_Type irqn) {
    if ((int32_t)irqn >= 0) {
        s_mock_nvic.ISER[(uint32_t)irqn >> 5UL] = (1UL << ((uint32_t)irqn & 0x1FUL));
    }
}

static inline void mock_NVIC_SetPriority(IRQn_Type irqn, uint32_t priority) {
    if ((int32_t)irqn >= 0) {
        s_mock_nvic.IP[(uint32_t)irqn] = (uint8_t)((priority << 4) & 0xFF);
    }
}

#define NVIC_EnableIRQ(irqn) mock_NVIC_EnableIRQ(irqn)
#define __NVIC_EnableIRQ(irqn) mock_NVIC_EnableIRQ(irqn)
#define NVIC_SetPriority(irqn, prio) mock_NVIC_SetPriority(irqn, prio)
#define __NVIC_SetPriority(irqn, prio) mock_NVIC_SetPriority(irqn, prio)

#undef __DSB
#undef __ISB
#undef __DMB
#define __DSB() do { __asm__ __volatile__("" ::: "memory"); } while(0)
#define __ISB() do { __asm__ __volatile__("" ::: "memory"); } while(0)
#define __DMB() do { __asm__ __volatile__("" ::: "memory"); } while(0)

/* Include learner implementation under test */
#include "pwm.c"

int main(void)
{
    /* =========================================================================
     * Test 1: pwm_init(72000000U) Hardware Register & Clock Configuration
     * ========================================================================= */
    memset(&s_mock_gpioa, 0, sizeof(s_mock_gpioa));
    memset(&s_mock_tim2, 0, sizeof(s_mock_tim2));
    memset(&s_mock_rcc, 0, sizeof(s_mock_rcc));
    memset(&s_mock_nvic, 0, sizeof(s_mock_nvic));

    if (!pwm_init(72000000U)) {
        fprintf(stderr, "ERROR: pwm_init(72000000U) returned false!\n");
        return 1;
    }

    /* 1.1 Peripheral Clocks */
    if (!(s_mock_rcc.APB1ENR & RCC_APB1ENR_TIM2EN)) {
        fprintf(stderr, "ERROR: TIM2 clock not enabled in RCC->APB1ENR (missing RCC_APB1ENR_TIM2EN)!\n");
        return 2;
    }
    if (!(s_mock_rcc.APB2ENR & RCC_APB2ENR_IOPAEN)) {
        fprintf(stderr, "ERROR: GPIOA clock not enabled in RCC->APB2ENR (missing RCC_APB2ENR_IOPAEN)!\n");
        return 3;
    }

    /* 1.2 Timer Prescaler & Auto-Reload */
    if (s_mock_tim2.PSC != 71) {
        fprintf(stderr, "ERROR: TIM2->PSC is %u, expected 71 (72 MHz / (71 + 1) = 1 MHz counter clock)!\n",
                s_mock_tim2.PSC);
        return 4;
    }
    if (s_mock_tim2.ARR != 99) {
        fprintf(stderr, "ERROR: TIM2->ARR is %u, expected 99 (1 MHz / (99 + 1) = 10 kHz tick frequency)!\n",
                s_mock_tim2.ARR);
        return 5;
    }

    /* 1.3 Timer Interrupt Enable and Counter Start */
    if (!(s_mock_tim2.DIER & TIM_DIER_UIE)) {
        fprintf(stderr, "ERROR: TIM2 Update Interrupt Enable (UIE) bit missing in TIM2->DIER!\n");
        return 6;
    }
    if (!(s_mock_tim2.CR1 & TIM_CR1_CEN)) {
        fprintf(stderr, "ERROR: TIM2 Counter Enable (CEN) bit missing in TIM2->CR1!\n");
        return 7;
    }

    /* 1.4 NVIC TIM2 Interrupt Enable */
    uint32_t tim2_nvic_enabled = s_mock_nvic.ISER[TIM2_IRQn >> 5UL] & (1UL << (TIM2_IRQn & 0x1FUL));
    if (!tim2_nvic_enabled) {
        fprintf(stderr, "ERROR: TIM2 interrupt not enabled in NVIC ISER register!\n");
        return 8;
    }

    /* 1.5 NVIC Priority Encoding (Cortex-M3 4-bit priority: priority 2 -> (2 << 4) = 0x20) */
    uint8_t tim2_prio = s_mock_nvic.IP[TIM2_IRQn];
    if (tim2_prio != (2U << 4)) {
        fprintf(stderr, "ERROR: TIM2 NVIC priority is 0x%02X, expected 0x%02X (logical priority 2 << 4)!\n",
                tim2_prio, (2U << 4));
        return 9;
    }

    /* =========================================================================
     * Test 2: Channel and Duty Percentage Acceptance & Rejection
     * ========================================================================= */
    /* 2.1 Explicit acceptance of 0, 1, 50, 99, 100 on all 4 valid channels */
    uint8_t valid_duties[] = {0, 1, 50, 99, 100};
    for (uint8_t ch = 0; ch < 4; ch++) {
        for (size_t i = 0; i < sizeof(valid_duties)/sizeof(valid_duties[0]); i++) {
            if (!pwm_set_duty(ch, valid_duties[i])) {
                fprintf(stderr, "ERROR: pwm_set_duty rejected valid duty %u on channel %u\n",
                        valid_duties[i], ch);
                return 10;
            }
            if (pwm_get_duty(ch) != valid_duties[i]) {
                fprintf(stderr, "ERROR: pwm_get_duty(%u) returned %u, expected %u\n",
                        ch, pwm_get_duty(ch), valid_duties[i]);
                return 11;
            }
        }

        /* 2.2 Rejection of duty > 100 */
        uint8_t invalid_duties[] = {101, 102, 150, 200, 255};
        for (size_t i = 0; i < sizeof(invalid_duties)/sizeof(invalid_duties[0]); i++) {
            if (pwm_set_duty(ch, invalid_duties[i])) {
                fprintf(stderr, "ERROR: pwm_set_duty accepted invalid duty %u on channel %u\n",
                        invalid_duties[i], ch);
                return 12;
            }
        }
    }

    /* 2.3 Rejection of channel >= 4 */
    for (uint8_t ch = 4; ch <= 8; ch++) {
        if (pwm_set_duty(ch, 50)) {
            fprintf(stderr, "ERROR: pwm_set_duty accepted invalid channel %u\n", ch);
            return 13;
        }
        if (pwm_get_duty(ch) != 0xFF) {
            fprintf(stderr, "ERROR: pwm_get_duty(%u) did not return 0xFF for invalid channel\n", ch);
            return 14;
        }
    }

    /* =========================================================================
     * Test 3: Deterministic Per-Step Output Mask & Duty Verification (0..99)
     * Setup: ch0=0%, ch1=1%, ch2=50%, ch3=100%
     * ========================================================================= */
    if (!pwm_set_duty(0, 0) ||
        !pwm_set_duty(1, 1) ||
        !pwm_set_duty(2, 50) ||
        !pwm_set_duty(3, 100)) {
        fprintf(stderr, "ERROR: Failed to configure deterministic test duties (0, 1, 50, 100)\n");
        return 15;
    }

    /* Synchronize step counter to step 0 by advancing until step 99 completes */
    for (int timeout = 0; timeout < 200; timeout++) {
        uint8_t s = pwm_step();
        if (s == 99) {
            break;
        }
    }

    /* Now verify exact output mask for all 100 steps (step 0 through 99) */
    for (uint8_t s = 0; s < 100; s++) {
        uint32_t expected_set = 0;
        uint32_t expected_rst = 0;
        for (uint8_t ch = 0; ch < 4; ch++) {
            uint8_t duty = (ch == 0) ? 0 : (ch == 1) ? 1 : (ch == 2) ? 50 : 100;
            if (s < duty) {
                expected_set |= (1U << ch);
            } else {
                expected_rst |= (1U << ch);
            }
        }

        s_mock_gpioa.BSRR = 0;
        s_mock_gpioa.BRR = 0;
        s_mock_gpioa.ODR = 0;

        uint8_t actual_step = pwm_step();
        if (actual_step != s) {
            fprintf(stderr, "ERROR: pwm_step() returned step %u, expected %u\n", actual_step, s);
            return 16;
        }

        /* Verify zero ODR modifications (no non-atomic RMW hazard) */
        if (s_mock_gpioa.ODR != 0) {
            fprintf(stderr, "ERROR: GPIOA->ODR was modified during pwm_step! Non-atomic RMW hazard detected.\n");
            return 17;
        }

        /* Capture actual set and reset masks from BSRR / BRR */
        uint32_t actual_set = s_mock_gpioa.BSRR & 0x000FU;
        uint32_t actual_rst = ((s_mock_gpioa.BSRR >> 16) | s_mock_gpioa.BRR) & 0x000FU;

        if (actual_set != expected_set) {
            fprintf(stderr, "ERROR: Step %u SET mask mismatch! Actual: 0x%X, Expected: 0x%X\n",
                    s, actual_set, expected_set);
            return 18;
        }
        if (actual_rst != expected_rst) {
            fprintf(stderr, "ERROR: Step %u RESET mask mismatch! Actual: 0x%X, Expected: 0x%X\n",
                    s, actual_rst, expected_rst);
            return 19;
        }
    }

    /* Next step after 99 must wrap back to 0 */
    s_mock_gpioa.BSRR = 0;
    s_mock_gpioa.BRR = 0;
    uint8_t wrap_step = pwm_step();
    if (wrap_step != 0) {
        fprintf(stderr, "ERROR: pwm_step() failed to wrap to 0 after step 99! Got %u\n", wrap_step);
        return 20;
    }

    /* =========================================================================
     * Test 4: TIM2_IRQHandler Execution & UIF Acknowledgement
     * ========================================================================= */
    /* 4.1 Valid Interrupt: UIF is asserted */
    s_mock_tim2.SR = TIM_SR_UIF;
    s_mock_gpioa.BSRR = 0;
    s_mock_gpioa.BRR = 0;

    TIM2_IRQHandler();

    /* Verify UIF flag was cleared in TIM2->SR */
    if (s_mock_tim2.SR & TIM_SR_UIF) {
        fprintf(stderr, "ERROR: TIM2_IRQHandler failed to acknowledge/clear TIM_SR_UIF flag!\n");
        return 21;
    }

    /* Verify PWM state actually advanced (BSRR/BRR write occurred) */
    if (s_mock_gpioa.BSRR == 0 && s_mock_gpioa.BRR == 0) {
        fprintf(stderr, "ERROR: TIM2_IRQHandler did not advance PWM state (no BSRR/BRR write)!\n");
        return 22;
    }

    /* 4.2 Spurious Interrupt: UIF is NOT asserted */
    s_mock_tim2.SR = 0;
    s_mock_gpioa.BSRR = 0;
    s_mock_gpioa.BRR = 0;

    TIM2_IRQHandler();

    /* Verify no PWM state advancement on spurious interrupt */
    if (s_mock_gpioa.BSRR != 0 || s_mock_gpioa.BRR != 0) {
        fprintf(stderr, "ERROR: TIM2_IRQHandler advanced PWM state even though UIF flag was not asserted!\n");
        return 23;
    }

    printf("ALL_HOST_PWM_TESTS_PASSED\n");
    return 0;
}

