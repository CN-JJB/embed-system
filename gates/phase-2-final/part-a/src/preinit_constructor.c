#include <stdint.h>

/* Boot token initialized by runtime constructor before main() */
volatile uint32_t g_boot_preinit_token = 0;

/**
 * @brief Hardware pre-initialization constructor.
 * Expected to be placed into .init_array and executed by __libc_init_array()
 * prior to main().
 */
__attribute__((constructor))
void system_peripheral_preinit(void)
{
    g_boot_preinit_token = 0x5A5AA5A5U;
}
