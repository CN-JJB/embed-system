# P2-M02 Challenge Solution: Direct-Register Multi-Channel Software PWM

> **Target Mastery**: L4-local register/MMIO interaction, L3 NVIC handling  
> **Challenge Goal**: Implement a 4-channel 100 Hz software PWM controller on GPIOA pins PA0–PA3 using TIM2 running at 10 kHz (100 us resolution) via direct CMSIS register access.

---

## 1. Diagnostic Mapping for Challenge Failures

```text
symptom
→ hypotheses
→ evidence
→ root cause
→ minimal fix
→ regression
```

### Case Study: PWM Frequency Off by Factor of 2 or Glitching under Preemption
- **Symptom**: Oscilloscope probe on PA0 shows PWM base frequency is 200 Hz instead of 100 Hz, or pulses on PA1/PA2 show occasional duty cycle jitter.
- **Hypotheses**:
  1. The student assumed timer input clock is PCLK1 (36 MHz) instead of recognizing the APB1 timer clock doubler ($36\text{ MHz} \times 2 = 72\text{ MHz}$).
  2. Pin manipulation used non-atomic read-modify-write on `GPIOA->ODR` rather than atomic `BSRR`/`BRR`.
  3. The interrupt acknowledge was placed after GPIO manipulation without `__DSB()`, causing delayed flag clearance.
- **Evidence**:
  Inspect timer prescaler registers in GDB:
  ```gdb
  print TIM2->PSC
  # PSC = 35 -> (35+1) gives 2 MHz counter clock, causing 100 us tick to take 50 us -> 200 Hz PWM!
  ```
- **Root Cause**:
  RM0008 Section 6.2 mandates that when APB1 prescaler is not `/1` (here it is `/2`), timer clock frequency is multiplied by 2. At 72 MHz SYSCLK, APB1 timer clock is 72 MHz, not 36 MHz.
- **Minimal Fix**:
  Calculate prescaler using 72 MHz:
  $$\text{PSC} = \frac{72000000}{1000000} - 1 = 71$$
  $$\text{ARR} = 99 \implies (71 + 1) \times (99 + 1) = 7200 \implies f_{\text{tick}} = 10\text{ kHz (100 }\mu\text{s)}$$
- **Regression**:
  Run `bash challenge/verify_challenge.sh` to confirm frequency arithmetic and build consistency.

---

## 2. Complete Reference Implementation

```c
#include "stm32f103xb.h"
#include "core_cm3.h"

static volatile uint8_t s_duty[4] = {25, 50, 75, 90}; /* Duty cycles 0-100% */
static volatile uint32_t s_step = 0;

void pwm_gpio_init(void)
{
    /* Enable GPIOA peripheral clock */
    RCC->APB2ENR |= RCC_APB2ENR_IOPAEN;

    /* Configure PA0-PA3 as Output Push-Pull, 50 MHz (MODE=0b11, CNF=0b00) */
    GPIOA->CRL &= ~0x0000FFFFU;
    GPIOA->CRL |=  0x00003333U;

    /* Initial state: all pins low */
    GPIOA->BRR = 0x000FU;
}

void pwm_timer_init(void)
{
    /* 1. Enable TIM2 peripheral clock */
    RCC->APB1ENR |= RCC_APB1ENR_TIM2EN;

    /* 2. Configure 10 kHz tick (100 us step) from 72 MHz timer clock */
    TIM2->PSC = 71;   /* 72 MHz / 72 = 1 MHz counter clock */
    TIM2->ARR = 99;   /* 100 ticks of 1 us = 100 us */
    TIM2->EGR = TIM_EGR_UG;
    TIM2->SR = ~TIM_SR_UIF;
    TIM2->DIER |= TIM_DIER_UIE;

    /* 3. Configure NVIC */
    NVIC_SetPriority(TIM2_IRQn, 5);
    NVIC_EnableIRQ(TIM2_IRQn);

    /* 4. Start timer */
    TIM2->CR1 |= TIM_CR1_CEN;
}

void TIM2_IRQHandler(void)
{
    if (TIM2->SR & TIM_SR_UIF) {
        TIM2->SR = ~TIM_SR_UIF;
        __DSB();

        s_step = (s_step + 1) % 100;

        if (s_step == 0) {
            /* Start of PWM period (100 Hz): set active channels atomically */
            uint32_t set_mask = 0;
            for (int ch = 0; ch < 4; ++ch) {
                if (s_duty[ch] > 0) {
                    set_mask |= (1U << ch);
                }
            }
            GPIOA->BSRR = set_mask;
        }

        /* End of active pulse: reset channels atomically */
        uint32_t rst_mask = 0;
        for (int ch = 0; ch < 4; ++ch) {
            if (s_step == s_duty[ch]) {
                rst_mask |= (1U << ch);
            }
        }
        if (rst_mask) {
            GPIOA->BRR = rst_mask;
        }
    }
}
```

---

## 3. Verification

Run automated validation:
```bash
bash challenge/verify_challenge.sh
```
Output:
```text
=== Verifying P2-M02 Challenge Requirements ===
[PASS] Timer frequency math verified: 72000000 / ((71 + 1) * (99 + 1)) = 10000 Hz (100 us tick)
[PASS] PWM base frequency verified: 10000 Hz / 100 steps = 100 Hz
[PASS] Module base firmware compiles cleanly with zero warnings
=== P2-M02 CHALLENGE SPECIFICATION VERIFIED ===
```
