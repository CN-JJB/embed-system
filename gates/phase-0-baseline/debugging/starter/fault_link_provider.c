#include <stdint.h>

static uint32_t checksum_word(uint32_t value)
{
    value ^= value >> 16;
    value *= 0x45d9f3bU;
    value ^= value >> 16;
    return value;
}

uint32_t provider_self_test(void)
{
    return checksum_word(0U);
}
