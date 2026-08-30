#include <stdint.h>
#include <stdio.h>

uint32_t checksum_word(uint32_t value);

int main(void)
{
    printf("checksum=%08x\n", checksum_word(0x12345678U));
    return 0;
}
