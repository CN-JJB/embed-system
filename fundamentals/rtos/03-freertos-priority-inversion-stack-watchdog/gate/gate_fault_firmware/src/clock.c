/**
 * =============================================================================
 * Clock Tree Configuration Implementation for STM32F103C8T6
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M04 FreeRTOS Scheduler, Task Lifecycle, and Context Switch
 * =============================================================================
 */

#include "clock.h"
#include "stm32f103xb.h"
#include "system_stm32f1xx.h"

#define HSE_STARTUP_TIMEOUT   0x00050000U
#define HSI_STARTUP_TIMEOUT   0x00010000U
#define PLL_LOCK_TIMEOUT      0x00050000U
#define SWS_SWITCH_TIMEOUT    0x00010000U

bool clock_init(clock_profile_t profile)
{
    uint32_t timeout = 0;

    if (profile == CLOCK_PROFILE_72MHZ_HSE) {
        /* --- PRIMARY PROFILE: 72 MHz SYSCLK via 8 MHz HSE --- */
        RCC->CR |= RCC_CR_HSEON;
        while (!(RCC->CR & RCC_CR_HSERDY)) {
            if (++timeout > HSE_STARTUP_TIMEOUT) {
                RCC->CR &= ~RCC_CR_HSEON;
                return false;
            }
        }

        FLASH->ACR = FLASH_ACR_PRFTBE | FLASH_ACR_LATENCY_2;

        RCC->CFGR = RCC_CFGR_HPRE_DIV1   |
                    RCC_CFGR_PPRE2_DIV1  |
                    RCC_CFGR_PPRE1_DIV2  |
                    RCC_CFGR_PLLSRC      |
                    RCC_CFGR_PLLMULL9;

        RCC->CR |= RCC_CR_PLLON;
        timeout = 0;
        while (!(RCC->CR & RCC_CR_PLLRDY)) {
            if (++timeout > PLL_LOCK_TIMEOUT) {
                RCC->CR &= ~RCC_CR_PLLON;
                RCC->CR &= ~RCC_CR_HSEON;
                RCC->CFGR &= ~RCC_CFGR_SW;
                FLASH->ACR = FLASH_ACR_LATENCY_0;
                SystemCoreClock = 8000000U;
                return false;
            }
        }

        RCC->CFGR &= ~RCC_CFGR_SW;
        RCC->CFGR |=  RCC_CFGR_SW_PLL;
        timeout = 0;
        while ((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_PLL) {
            if (++timeout > SWS_SWITCH_TIMEOUT) {
                RCC->CFGR &= ~RCC_CFGR_SW;
                RCC->CR &= ~RCC_CR_PLLON;
                RCC->CR &= ~RCC_CR_HSEON;
                FLASH->ACR = FLASH_ACR_LATENCY_0;
                SystemCoreClock = 8000000U;
                return false;
            }
        }

        SystemCoreClock = 72000000U;
        return true;

    } else {
        /* --- FALLBACK PROFILE: 64 MHz SYSCLK via 8 MHz HSI --- */
        RCC->CR |= RCC_CR_HSION;
        while (!(RCC->CR & RCC_CR_HSIRDY)) {
            if (++timeout > HSI_STARTUP_TIMEOUT) {
                return false;
            }
        }

        FLASH->ACR = FLASH_ACR_PRFTBE | FLASH_ACR_LATENCY_2;

        /* HSI / 2 * 16 = 64 MHz, APB1 /2 (32 MHz) */
        RCC->CFGR = RCC_CFGR_HPRE_DIV1   |
                    RCC_CFGR_PPRE2_DIV1  |
                    RCC_CFGR_PPRE1_DIV2  |
                    RCC_CFGR_PLLMULL16;

        RCC->CR |= RCC_CR_PLLON;
        timeout = 0;
        while (!(RCC->CR & RCC_CR_PLLRDY)) {
            if (++timeout > PLL_LOCK_TIMEOUT) {
                RCC->CR &= ~RCC_CR_PLLON;
                RCC->CFGR &= ~RCC_CFGR_SW;
                FLASH->ACR = FLASH_ACR_LATENCY_0;
                SystemCoreClock = 8000000U;
                return false;
            }
        }

        RCC->CFGR &= ~RCC_CFGR_SW;
        RCC->CFGR |=  RCC_CFGR_SW_PLL;
        timeout = 0;
        while ((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_PLL) {
            if (++timeout > SWS_SWITCH_TIMEOUT) {
                RCC->CFGR &= ~RCC_CFGR_SW;
                RCC->CR &= ~RCC_CR_PLLON;
                FLASH->ACR = FLASH_ACR_LATENCY_0;
                SystemCoreClock = 8000000U;
                return false;
            }
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
            uint32_t hse_div = (RCC->CFGR & RCC_CFGR_PLLXTPRE) ? 2 : 1;
            sysclk = (8000000U / hse_div) * pllmull;
        } else {
            sysclk = (8000000U / 2) * pllmull;
        }
    } else if (sws == RCC_CFGR_SWS_HSE) {
        sysclk = 8000000U;
    } else {
        sysclk = 8000000U;
    }

    freqs->sysclk_hz = sysclk;

    static const uint8_t ahb_div_table[16] = {
        0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 6, 7, 8, 9
    };
    uint32_t hpre = (RCC->CFGR & RCC_CFGR_HPRE) >> 4;
    freqs->hclk_hz = sysclk >> ahb_div_table[hpre];

    static const uint8_t apb_div_table[8] = { 0, 0, 0, 0, 1, 2, 3, 4 };
    uint32_t ppre1 = (RCC->CFGR & RCC_CFGR_PPRE1) >> 8;
    freqs->pclk1_hz = freqs->hclk_hz >> apb_div_table[ppre1];

    uint32_t ppre2 = (RCC->CFGR & RCC_CFGR_PPRE2) >> 11;
    freqs->pclk2_hz = freqs->hclk_hz >> apb_div_table[ppre2];
}
