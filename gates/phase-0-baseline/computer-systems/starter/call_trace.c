#include <stdio.h>

__attribute__((noinline))
static long mix(long a, long b, long c)
{
    long local = (a + b) * c;
    return local - b;
}

int main(void)
{
    long result = mix(3, 5, 7);
    printf("result=%ld\n", result);
    return 0;
}
