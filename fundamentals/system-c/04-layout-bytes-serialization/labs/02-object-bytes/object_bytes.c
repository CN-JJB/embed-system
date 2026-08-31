#include <limits.h>
#include <stdint.h>
#include <stdio.h>

static void dump_object(const void *obj, size_t n)
{
    const unsigned char *p = obj;
    for (size_t i = 0; i < n; ++i) printf("%02x%s", (unsigned)p[i], i + 1 == n ? "\n" : " ");
}

int main(void)
{
    uint32_t x = UINT32_C(0x11223344);
    printf("CHAR_BIT=%d sizeof(x)=%zu\n", CHAR_BIT, sizeof x);
    dump_object(&x, sizeof x);
    puts("The byte order above is an observation of this host, not a universal golden vector.");
    return 0;
}
