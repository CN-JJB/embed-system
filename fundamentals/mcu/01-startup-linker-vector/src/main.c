/**
 * =============================================================================
 * Main Application for Module P2-M01: Bare-Metal Boot Verification
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M01 Reset, Startup, Linker Script, and Vector Table
 *
 * Verifies:
 *   1. .data copy: initialized global variables contain expected values.
 *   2. .bss zero: uninitialized variables start at zero.
 *   3. .init_array: C constructors execute before main().
 *   4. Direct MMIO register access toggling PC13 LED.
 * =============================================================================
 */

#include <stdint.h>
#include "stm32f103xb.h"
#include "system_stm32f1xx.h"

/* --- Test Object Invariants --- */

/* 1. Initialized global in .data section (VMA in RAM, LMA in Flash) */
volatile uint32_t g_boot_magic = 0xA5C3E107U;

/* 2. Uninitialized global in .bss section (VMA in RAM, zeroed at startup) */
volatile uint32_t g_zero_bss_check;

/* 3. Constructor flag verified via .init_array table */
volatile uint32_t g_constructor_ran = 0U;

/* Constructor function called by __libc_init_array() before main() */
__attribute__((constructor))
static void early_constructor_hook(void)
{
    g_constructor_ran = 0x55AA55AAU;
}

/* Minimal delay loop for bare-metal observation */
static void delay_cycles(volatile uint32_t cycles)
{
    while (cycles > 0) {
        cycles--;
    }
}

int main(void)
{
    /* Validation 1: Verify .data section copy */
    if (g_boot_magic != 0xA5C3E107U) {
        /* Failed: .data was not copied from Flash LMA to RAM VMA */
        while (1) {
            __NOP();
        }
    }

    /* Validation 2: Verify .bss section zeroing */
    if (g_zero_bss_check != 0U) {
        /* Failed: .bss was not zeroed out in RAM */
        while (1) {
            __NOP();
        }
    }

    /* Validation 3: Verify __libc_init_array executed constructor */
    if (g_constructor_ran != 0x55AA55AAU) {
        /* Failed: .init_array constructor was not invoked */
        while (1) {
            __NOP();
        }
    }

    /* Hardware Bring-Up: Enable GPIOC clock in RCC (APB2 peripheral clock)
     * Bit 4 of RCC_APB2ENR is IOPCEN (I/O port C clock enable)
     */
    RCC->APB2ENR |= RCC_APB2ENR_IOPCEN;

    /* Configure PC13 as General Purpose Output Push-Pull, max speed 2 MHz
     * PC13 configuration bits reside in CRH (Control Register High):
     * Bits [23:20] for Pin 13:
     *   CNF13[1:0] = 00 (General purpose output push-pull)
     *   MODE13[1:0] = 10 (Output mode, max speed 2 MHz)
     */
    GPIOC->CRH &= ~(0xFU << 20);
    GPIOC->CRH |=  (0x2U << 20);

    /* Toggle PC13 LED (Active LOW on STM32 Blue Pill board) */
    while (1) {
        /* Atomic reset of bit 13 via BRR (LED ON) */
        GPIOC->BRR = (1U << 13);
        delay_cycles(200000);

        /* Atomic set of bit 13 via BSRR (LED OFF) */
        GPIOC->BSRR = (1U << 13);
        delay_cycles(200000);
    }

    return 0;
}
