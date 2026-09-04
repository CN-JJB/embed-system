/**
 * =============================================================================
 * Clock Tree Configuration Implementation for STM32F103C8T6
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M02 MMIO, Clock Tree, Hardware Timers, and NVIC Mechanism
 *
 * Mechanism Notes:
 * 1. Flash Memory Latency:
 *    According to RM0008 Section 3.3.3 Table 5:
 *      0 wait states: 0 < SYSCLK <= 24 MHz
 *      1 wait state: 24 MHz < SYSCLK <= 48 MHz
 *      2 wait states: 48 MHz < SYSCLK <= 72 MHz
 *    Flash latency MUST be increased BEFORE switching SYSCLK to a higher frequency!
 *
 * 2. APB1 Frequency Limit:
 *    RM0008 Section 6.2: APB1 max frequency is 36 MHz!
 *    At SYSCLK = 72 MHz, APB1 prescaler MUST be at least /2 (HCLK / 2 = 36 MHz).
 *
 * 3. Timer Clock Doubling Rule:
 *    RM0008 Section 6.2:
 *    If APB prescaler division factor == 1, timer clock = APB clock.
 *    If APB prescaler division factor > 1 (e.g. /2, /4, /8, /16), timer clock = APB clock * 2!
 *    Therefore:
 *      Primary Profile: APB1 prescaler = /2 -> PCLK1 = 36 MHz -> TIM2 clock = 36 * 2 = 72 MHz!
 *      Fallback Profile: APB1 prescaler = /2 -> PCLK1 = 32 MHz -> TIM2 clock = 32 * 2 = 64 MHz!
 * =============================================================================
 */

#include "clock.h"
#include "stm32f103xb.h"
#include "system_stm32f1xx.h"

#define HSE_STARTUP_TIMEOUT   0x00050000U
#define HSI_STARTUP_TIMEOUT   0x00010000U

bool clock_init(clock_profile_t profile)
{
    uint32_t timeout = 0;

    if (profile == CLOCK_PROFILE_72MHZ_HSE) {
        /* --- PRIMARY PROFILE: 72 MHz SYSCLK via 8 MHz HSE --- */

        /* 1. Enable HSE (High-Speed External oscillator) */
        RCC->CR |= RCC_CR_HSEON;
        while (!(RCC->CR & RCC_CR_HSERDY)) {
            if (++timeout > HSE_STARTUP_TIMEOUT) {
                /* HSE failed to stabilize: fallback to safe HSI profile */
                return clock_init(CLOCK_PROFILE_64MHZ_HSI);
            }
        }

        /* 2. Configure Flash Memory:
         *    Enable Prefetch Buffer and configure 2 Wait States (SYSCLK > 48 MHz)
         */
        FLASH->ACR = FLASH_ACR_PRFTBE | FLASH_ACR_LATENCY_2;

        /* 3. Configure Bus Dividers and PLL:
         *    HCLK (AHB)  = SYSCLK / 1   = 72 MHz
         *    PCLK2 (APB2) = HCLK / 1    = 72 MHz
         *    PCLK1 (APB1) = HCLK / 2    = 36 MHz (Max APB1 is 36 MHz!)
         *    PLL Source   = HSE (8 MHz)
         *    PLL Multiplier = x9 (8 MHz * 9 = 72 MHz)
         */
        RCC->CFGR = RCC_CFGR_HPRE_DIV1   |  /* AHB prescaler: /1 */
                    RCC_CFGR_PPRE2_DIV1  |  /* APB2 prescaler: /1 */
                    RCC_CFGR_PPRE1_DIV2  |  /* APB1 prescaler: /2 (36 MHz max) */
                    RCC_CFGR_PLLSRC      |  /* PLL entry clock: HSE */
                    RCC_CFGR_PLLMULL9;      /* PLL multiplication factor: x9 */

        /* 4. Enable PLL */
        RCC->CR |= RCC_CR_PLLON;
        while (!(RCC->CR & RCC_CR_PLLRDY)) {
            /* Wait for PLL to lock */
        }

        /* 5. Select PLL as system clock source */
        RCC->CFGR &= ~RCC_CFGR_SW;
        RCC->CFGR |=  RCC_CFGR_SW_PLL;
        while ((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_PLL) {
            /* Wait until PLL is used as system clock source */
        }

        SystemCoreClock = 72000000U;
        return true;

    } else {
        /* --- FALLBACK PROFILE: 64 MHz SYSCLK via 8 MHz HSI --- */

        /* 1. Ensure HSI is enabled and stable */
        RCC->CR |= RCC_CR_HSION;
        while (!(RCC->CR & RCC_CR_HSIRDY)) {
            if (++timeout > HSI_STARTUP_TIMEOUT) {
                return false;
            }
        }

        /* 2. Configure Flash Memory: 2 Wait States for 64 MHz */
        FLASH->ACR = FLASH_ACR_PRFTBE | FLASH_ACR_LATENCY_2;

        /* 3. Configure Bus Dividers and PLL:
         *    HSI on STM32F1 is divided by 2 before PLL entry (8 MHz / 2 = 4 MHz).
         *    PLL Multiplier = x16 (4 MHz * 16 = 64 MHz)
         *    HCLK (AHB)  = SYSCLK / 1   = 64 MHz
         *    PCLK2 (APB2) = HCLK / 1    = 64 MHz
         *    PCLK1 (APB1) = HCLK / 2    = 32 MHz (Max APB1 is 36 MHz)
         */
        RCC->CFGR = RCC_CFGR_HPRE_DIV1   |  /* AHB /1 */
                    RCC_CFGR_PPRE2_DIV1  |  /* APB2 /1 */
                    RCC_CFGR_PPRE1_DIV2  |  /* APB1 /2 (32 MHz) */
                    RCC_CFGR_PLLMULL16;     /* PLL x16 (HSI/2 * 16 = 64 MHz) */

        /* 4. Enable PLL */
        RCC->CR |= RCC_CR_PLLON;
        while (!(RCC->CR & RCC_CR_PLLRDY)) {
            /* Wait for PLL to lock */
        }

        /* 5. Select PLL as system clock */
        RCC->CFGR &= ~RCC_CFGR_SW;
        RCC->CFGR |=  RCC_CFGR_SW_PLL;
        while ((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_PLL) {
            /* Wait until PLL is selected */
        }

        SystemCoreClock = 64000000U;
        return true;
    }
}

void clock_get_frequencies(clock_frequencies_t *freqs)
{
    if (!freqs) return;

    uint32_t sysclk = 8000000U;
    uint32_t sws = (RCC->CFGR & RCC_CFGR_SWS);

    if (sws == RCC_CFGR_SWS_PLL) {
        uint32_t pllmull = ((RCC->CFGR & RCC_CFGR_PLLMULL) >> 18) + 2;
        if (RCC->CFGR & RCC_CFGR_PLLSRC) {
            /* HSE source */
            uint32_t hse_div = (RCC->CFGR & RCC_CFGR_PLLXTPRE) ? 2 : 1;
            sysclk = (8000000U / hse_div) * pllmull;
        } else {
            /* HSI / 2 source */
            sysclk = (8000000U / 2) * pllmull;
        }
    } else if (sws == RCC_CFGR_SWS_HSE) {
        sysclk = 8000000U;
    } else {
        sysclk = 8000000U;
    }

    freqs->sysclk_hz = sysclk;

    /* AHB Prescaler */
    static const uint8_t ahb_div_table[16] = {
        0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 6, 7, 8, 9
    };
    uint32_t hpre = (RCC->CFGR & RCC_CFGR_HPRE) >> 4;
    freqs->hclk_hz = sysclk >> ahb_div_table[hpre];

    /* APB1 Prescaler */
    static const uint8_t apb_div_table[8] = { 0, 0, 0, 0, 1, 2, 3, 4 };
    uint32_t ppre1 = (RCC->CFGR & RCC_CFGR_PPRE1) >> 8;
    freqs->pclk1_hz = freqs->hclk_hz >> apb_div_table[ppre1];

    /* Timer 1 Clock Doubling Rule: if APB1 prescaler != 1, timclk = pclk1 * 2 */
    if (apb_div_table[ppre1] == 0) {
        freqs->timclk1_hz = freqs->pclk1_hz;
    } else {
        freqs->timclk1_hz = freqs->pclk1_hz * 2;
    }

    /* APB2 Prescaler */
    uint32_t ppre2 = (RCC->CFGR & RCC_CFGR_PPRE2) >> 11;
    freqs->pclk2_hz = freqs->hclk_hz >> apb_div_table[ppre2];

    /* APB2 Timer Clock Doubling Rule */
    if (apb_div_table[ppre2] == 0) {
        freqs->timclk2_hz = freqs->pclk2_hz;
    } else {
        freqs->timclk2_hz = freqs->pclk2_hz * 2;
    }
}
