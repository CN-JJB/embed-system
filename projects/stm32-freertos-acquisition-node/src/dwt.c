/**
 * =============================================================================
 * Cortex-M3 DWT Cycle Counter Driver for STM32F103C8T6
 * =============================================================================
 * Course: Embedded Systems Foundations - Phase 2 MCU & FreeRTOS
 * Project: P2-M07 STM32 FreeRTOS Acquisition Node Integration Project
 * =============================================================================
 */

#include "dwt.h"
#include "stm32f103xb.h"
#include "core_cm3.h"

void __attribute__((noinline)) dwt_init(void)
{
    /* Enable Trace System (TRCENA) in Debug Exception and Monitor Control Register */
    CoreDebug->DEMCR |= CoreDebug_DEMCR_TRCENA_Msk;

    /* Reset cycle counter to 0 */
    DWT->CYCCNT = 0U;

    /* Enable DWT Cycle Counter (CYCCNTENA) */
    DWT->CTRL |= DWT_CTRL_CYCCNTENA_Msk;
}

uint32_t __attribute__((noinline)) dwt_get_cycles(void)
{
    return DWT->CYCCNT;
}
