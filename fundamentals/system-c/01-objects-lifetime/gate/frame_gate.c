#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct view {
    const uint8_t *data;
    size_t len;
};

static unsigned sum_bytes(struct view v)
{
    unsigned sum = 0;
    const uint8_t *end = v.data + v.len; /* legal one-past construction */
    for (const uint8_t *p = v.data; p != end; ++p) sum += *p;
    return sum;
}

static void dump_view(const char *label, struct view v)
{
    printf("%s data=%p len=%zu bytes=", label, (const void *)v.data, v.len);
    size_t shown = v.len < 6 ? v.len : 6;
    for (size_t i = 0; i < shown; ++i) {
        printf("%02x", (unsigned)v.data[i]);
        if (i + 1 != shown) putchar(':');
    }
    if (shown < v.len) printf(":...");
    putchar('\n');
}

static int extent_case(void)
{
    uint8_t frame[10] = {0x42, 0x0c, 1, 2, 3, 4, 5, 6, 0xee, 0xee};
    size_t declared_payload = frame[1];
    struct view payload = { &frame[2], declared_payload };

    printf("frame_bytes=%zu declared_payload=%zu\n", sizeof frame, declared_payload);
    dump_view("payload", payload);
    printf("payload checksum=%u\n", sum_bytes(payload));
    return 0;
}

static struct view remember_temporary(void)
{
    struct view out = {0};
    {
        uint8_t temporary[4] = {9, 8, 7, 6};
        out.data = temporary;
        out.len = sizeof temporary;
        printf("temporary address=%p\n", (void *)temporary);
    }
    return out;
}

static int lifetime_case(void)
{
    struct view v = remember_temporary();
    printf("remembered address=%p sum=%u\n", (const void *)v.data, sum_bytes(v));
    return 0;
}

static int ub_case(void)
{
    volatile int count = INT_MAX;
    int total = count + 1;
    unsigned shift = 31;
    int mask = 1 << shift;
    printf("total=%d mask=%d\n", total, mask);
    return 0;
}

static int legal_case(void)
{
    uint8_t bytes[] = {4, 3, 2, 1};
    struct view v = {bytes, sizeof bytes};
    const uint8_t *end = v.data + v.len;
    dump_view("legal", v);
    printf("begin=%p end(one-past)=%p sum=%u\n",
           (void *)v.data, (void *)end, sum_bytes(v));
    return 0;
}

static void usage(const char *prog)
{
    fprintf(stderr, "usage: %s extent|lifetime|ub|legal\n", prog);
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        usage(argv[0]);
        return 2;
    }
    if (strcmp(argv[1], "extent") == 0) return extent_case();
    if (strcmp(argv[1], "lifetime") == 0) return lifetime_case();
    if (strcmp(argv[1], "ub") == 0) return ub_case();
    if (strcmp(argv[1], "legal") == 0) return legal_case();
    usage(argv[0]);
    return 2;
}
