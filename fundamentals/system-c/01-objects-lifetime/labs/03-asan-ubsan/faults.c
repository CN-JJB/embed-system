#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int fault_oob(void)
{
    unsigned char *p = malloc(8);
    if (p == NULL) return 2;
    memset(p, 0x41, 8);
    p[8] = 0x42; /* deliberate out-of-bounds */
    printf("oob run completed, p[0]=%u\n", (unsigned)p[0]);
    free(p);
    return 0;
}

static int fault_dangling(void)
{
    int *p = malloc(sizeof *p);
    if (p == NULL) return 2;
    *p = 1234;
    free(p);
    printf("dangling read=%d\n", *p); /* deliberate use-after-free */
    return 0;
}

static int fault_signed_overflow(void)
{
    volatile int x = INT_MAX;
    int overflow = x + 1;       /* deliberate signed overflow */
    printf("overflow=%d\n", overflow);
    return 0;
}

static int fault_signed_shift(void)
{
    volatile int one = 1;
    int shifted = one << 31;    /* deliberate invalid signed shift */
    printf("shifted=%d\n", shifted);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "usage: %s oob|dangling|signed-overflow|signed-shift\n", argv[0]);
        return 2;
    }
    if (strcmp(argv[1], "oob") == 0) return fault_oob();
    if (strcmp(argv[1], "dangling") == 0) return fault_dangling();
    if (strcmp(argv[1], "signed-overflow") == 0) return fault_signed_overflow();
    if (strcmp(argv[1], "signed-shift") == 0) return fault_signed_shift();
    fprintf(stderr, "unknown fault: %s\n", argv[1]);
    return 2;
}
