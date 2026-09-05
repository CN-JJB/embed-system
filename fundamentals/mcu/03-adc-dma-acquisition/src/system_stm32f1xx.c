/**
 * =============================================================================
 * System Initialization Implementation for STM32F103xB
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M01 Reset, Startup, Linker Script, and Vector Table
 *
 * Invariant Verification:
 *   Reset_Handler calls SystemInit() at reset before copying .data and clearing
 *   .bss. SystemInit() must not write to any global variables (such as
 *   SystemCoreClock) because any write would be overwritten during the .data
 *   copy loop or .bss zero loop!
 * =============================================================================
 */

#include <stdint.h>
#include "stm32f103xb.h"
#include "system_stm32f1xx.h"

/* Default HSI clock frequency */
#define HSI_VALUE_DEFAULT   8000000U

/* Global clock tracking variable, allocated in .data section */
uint32_t SystemCoreClock = HSI_VALUE_DEFAULT;

void SystemInit(void)
{
    /* Set HSION bit to ensure internal 8 MHz RC oscillator is enabled */
    RCC->CR |= (uint32_t)0x00000001U;

    /* Reset SW, HPRE, PPRE1, PPRE2, ADCPRE, MCO bits */
    RCC->CFGR &= (uint32_t)0xF8FF0000U;

    /* Reset HSEON, CSSON, and PLLON bits */
    RCC->CR &= (uint32_t)0xFEF6FFFFU;

    /* Reset HSEBYP bit */
    RCC->CR &= (uint32_t)0xFFFBFFFFU;

    /* Reset PLLSRC, PLLXTPRE, PLLMUL, and USBPRE bits */
    RCC->CFGR &= (uint32_t)0xFF80FFFFU;

    /* Disable all RCC interrupts and clear flags */
    RCC->CIR = (uint32_t)0x009F0000U;

    /* Configure Vector Table base address to Flash (0x08000000) */
    SCB->VTOR = FLASH_BASE | 0x00000000U;

    /* NOTE: SystemCoreClock is intentionally NOT modified here.
     * Modifying a .data or .bss variable here would violate the early-startup
     * invariant, as .data has not yet been copied and .bss not zeroed.
     */
}

void SystemCoreClockUpdate(void)
{
    /* Calculate current core clock based on RCC configuration */
    uint32_t sysclk;
    uint32_t sws = (RCC->CFGR & RCC_CFGR_SWS);

    switch (sws) {
        case RCC_CFGR_SWS_HSI:
            sysclk = HSI_VALUE_DEFAULT;
            break;
        case RCC_CFGR_SWS_HSE:
            sysclk = 8000000U; /* HSE crystal default */
            break;
        case RCC_CFGR_SWS_PLL: {
            uint32_t pllmull = ((RCC->CFGR & RCC_CFGR_PLLMULL) >> 18) + 2;
            uint32_t pllsrc = RCC->CFGR & RCC_CFGR_PLLSRC;
            if (pllsrc == 0) {
                /* HSI / 2 */
                sysclk = (HSI_VALUE_DEFAULT >> 1) * pllmull;
            } else {
                /* HSE */
                if (RCC->CFGR & RCC_CFGR_PLLXTPRE) {
                    sysclk = (8000000U >> 1) * pllmull;
                } else {
                    sysclk = 8000000U * pllmull;
                }
            }
            break;
        }
        default:
            sysclk = HSI_VALUE_DEFAULT;
            break;
    }

    /* AHB prescaler division table */
    static const uint8_t AHBPrescTable[16] = {
        0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 6, 7, 8, 9
    };
    uint32_t hpre = (RCC->CFGR & RCC_CFGR_HPRE) >> 4;
    SystemCoreClock = sysclk >> AHBPrescTable[hpre];
}
