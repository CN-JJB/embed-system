#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

struct view { const uint8_t *data; size_t len; };

static unsigned sum_bytes(struct view v)
{
    unsigned sum = 0;
    const uint8_t *end = v.data + v.len;
    for (const uint8_t *p = v.data; p != end; ++p) sum += *p;
    return sum;
}

static int extent_case(void)
{
    uint8_t frame[10] = {0x42, 0x0c, 1, 2, 3, 4, 5, 6, 0xee, 0xee};
    size_t declared = frame[1];
    size_t available = sizeof frame - 2;
    if (declared > available) {
        fprintf(stderr, "invalid frame: declared=%zu available=%zu\n", declared, available);
        return 1;
    }
    printf("payload checksum=%u\n", sum_bytes((struct view){&frame[2], declared}));
    return 0;
}

static int lifetime_case(void)
{
    uint8_t storage[4] = {9, 8, 7, 6};
    struct view v = {storage, sizeof storage};
    printf("sum=%u\n", sum_bytes(v));
    return 0;
}

static int ub_case(void)
{
    int count = INT_MAX;
    if (count == INT_MAX) {
        puts("count increment rejected: would overflow");
    }
    uint32_t mask = UINT32_C(1) << 31;
    printf("mask=%#x\n", (unsigned)mask);
    return 0;
}

static int legal_case(void)
{
    uint8_t bytes[] = {4, 3, 2, 1};
    struct view v = {bytes, sizeof bytes};
    const uint8_t *end = v.data + v.len;
    printf("end=%p sum=%u\n", (const void *)end, sum_bytes(v));
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2) return 2;
    if (strcmp(argv[1], "extent") == 0) return extent_case();
    if (strcmp(argv[1], "lifetime") == 0) return lifetime_case();
    if (strcmp(argv[1], "ub") == 0) return ub_case();
    if (strcmp(argv[1], "legal") == 0) return legal_case();
    return 2;
}
