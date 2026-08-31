#include <stdio.h>

int initialized_global = 17;
int zero_global;
unsigned char zero_buffer[4096];
static int file_static_initialized = 5;
static const int thresholds[] = {2, 4, 8, 16};

static int helper(int value)
{
    return value + file_static_initialized + thresholds[1];
}

int main(void)
{
    const char *message = "ELF section evidence";
    zero_global = helper(initialized_global);
    zero_buffer[0] = (unsigned char)zero_global;
    printf("%s value=%d byte0=%u\n", message, zero_global, zero_buffer[0]);
    return 0;
}
