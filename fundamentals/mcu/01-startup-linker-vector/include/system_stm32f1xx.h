/**
 * =============================================================================
 * System Initialization Header for STM32F103xB
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M01 Reset, Startup, Linker Script, and Vector Table
 * =============================================================================
 */

#ifndef SYSTEM_STM32F1XX_H
#define SYSTEM_STM32F1XX_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

/**
 * @brief Core clock frequency variable in Hertz.
 * Note: Resides in .data or .bss. SystemInit() must NEVER write to this
 * variable before the startup code copies .data and zeroes .bss!
 */
extern uint32_t SystemCoreClock;

/**
 * @brief Setup the microcontroller system.
 *
 * CRITICAL PEDAGOGICAL INVARIANT:
 *   SystemInit() is called by Reset_Handler BEFORE .data is copied from Flash
 *   to RAM and BEFORE .bss is zeroed.
 *   Therefore, SystemInit() MUST NOT depend on or write to any initialized
 *   writable global or static C variables!
 *   It accesses only MMIO registers, core registers, and local stack frames.
 */
void SystemInit(void);

/**
 * @brief Update SystemCoreClock variable according to RCC register values.
 * Must only be called AFTER .data and .bss initialization is complete.
 */
void SystemCoreClockUpdate(void);

#ifdef __cplusplus
}
#endif

#endif /* SYSTEM_STM32F1XX_H */
