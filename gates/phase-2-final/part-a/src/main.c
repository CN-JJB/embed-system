#include <stdint.h>
#include "stm32f103xb.h"
#include "system_stm32f1xx.h"

extern volatile uint32_t g_boot_preinit_token;

volatile uint32_t g_main_cycles = 0;
volatile uint32_t g_boot_status = 0;

int main(void)
{
    /* Verify that pre-main constructor initialization was executed */
    if (g_boot_preinit_token != 0x5A5AA5A5U) {
        /* Constructor did not execute! Trap in fault loop. */
        g_boot_status = 0xDEADBEEFU;
        while (1) {
            __NOP();
        }
    }

    /* Pre-initialization invariant satisfied */
    g_boot_status = 0x00000001U;

    while (1) {
        g_main_cycles++;
    }

    return 0;
}
