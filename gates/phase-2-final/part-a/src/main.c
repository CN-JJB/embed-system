#include <stdint.h>
#include "stm32f103xb.h"
#include "system_stm32f1xx.h"

/* Read-only constant configuration metadata stored in .rodata */
static const char g_part_a_banner[] = "PART_A_STARTUP_REASONING_STM32F103";
static const uint32_t g_firmware_build_id = 0x20260907U;

/* Initialized runtime configuration resident in .data */
volatile uint32_t g_boot_config_token = 0x5A5AA5A5U;
volatile uint32_t g_main_cycles = 0;
volatile uint32_t g_boot_status = 0;

int main(void)
{
    /* Suppress unused variable warning while guaranteeing .rodata allocation */
    (void)g_part_a_banner;
    (void)g_firmware_build_id;

    /* Verify that runtime .data section was correctly relocated from Flash LMA */
    if (g_boot_config_token != 0x5A5AA5A5U) {
        /* Relocated data is corrupted! Trap in fault loop. */
        g_boot_status = 0xDEADBEEFU;
        while (1) {
            __NOP();
        }
    }

    /* Runtime data initialization invariant satisfied */
    g_boot_status = 0x00000001U;

    while (1) {
        g_main_cycles++;
    }

    return 0;
}
