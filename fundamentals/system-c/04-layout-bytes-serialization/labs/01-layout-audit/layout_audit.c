#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

struct sample_a { uint8_t type; uint32_t value; uint16_t flags; };
struct sample_b { uint32_t value; uint16_t flags; uint8_t type; };
struct sample_c { uint16_t flags; uint8_t type; uint32_t value; };

#define SHOW(T, M) printf("%-8s %-8s offset=%zu\n", #T, #M, offsetof(struct T, M))

int main(void)
{
    printf("sample_a size=%zu align=%zu\n", sizeof(struct sample_a), _Alignof(struct sample_a));
    SHOW(sample_a, type); SHOW(sample_a, value); SHOW(sample_a, flags);
    printf("sample_b size=%zu align=%zu\n", sizeof(struct sample_b), _Alignof(struct sample_b));
    SHOW(sample_b, value); SHOW(sample_b, flags); SHOW(sample_b, type);
    printf("sample_c size=%zu align=%zu\n", sizeof(struct sample_c), _Alignof(struct sample_c));
    SHOW(sample_c, flags); SHOW(sample_c, type); SHOW(sample_c, value);
    { struct sample_a a[2] = {{0}}; printf("array stride sample_a=%td\n", (ptrdiff_t)((char *)&a[1] - (char *)&a[0])); }
    return 0;
}
