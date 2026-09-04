#include <stdint.h>

/* Allocates 25 KB of uninitialized data in .bss, exceeding the physical 20 KB SRAM limit */
volatile uint8_t g_large_sram_buffer[25 * 1024];

int main(void)
{
    g_large_sram_buffer[0] = 0xAA;
    while (1);
    return 0;
}
