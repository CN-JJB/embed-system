#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define WIRE 12u
struct rec {
    uint8_t version;
    uint8_t kind;
    uint16_t flags;
    uint32_t value;
    uint32_t sequence;
};

_Static_assert(CHAR_BIT == 8, "wire format is defined in 8-bit octets");

static void p16(unsigned char *p, uint16_t v)
{
    p[0] = (unsigned char)v;
    p[1] = (unsigned char)(v >> 8);
}

static void p32(unsigned char *p, uint32_t v)
{
    for (unsigned i = 0; i < 4; ++i)
        p[i] = (unsigned char)(v >> (8u * i));
}

static uint16_t g16(const unsigned char *p)
{
    return (uint16_t)((uint16_t)p[0] | ((uint16_t)p[1] << 8));
}

static uint32_t g32(const unsigned char *p)
{
    return (uint32_t)p[0] |
           ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) |
           ((uint32_t)p[3] << 24);
}

static int same_rec(const struct rec *a, const struct rec *b)
{
    return a->version == b->version &&
           a->kind == b->kind &&
           a->flags == b->flags &&
           a->value == b->value &&
           a->sequence == b->sequence;
}

static int enc(unsigned char *out, size_t n, const struct rec *r)
{
    if (!out || !r || r->version != 1) return EINVAL;
    if (n < WIRE) return EMSGSIZE;
    out[0] = r->version;
    out[1] = r->kind;
    p16(out + 2, r->flags);
    p32(out + 4, r->value);
    p32(out + 8, r->sequence);
    return 0;
}

static int dec(struct rec *d, const unsigned char *b, size_t n)
{
    struct rec t;
    if (!d || !b) return EINVAL;
    if (n < WIRE) return EMSGSIZE;
    if (b[0] != 1) return EINVAL;
    t.version = b[0];
    t.kind = b[1];
    t.flags = g16(b + 2);
    t.value = g32(b + 4);
    t.sequence = g32(b + 8);
    *d = t;
    return 0;
}

int main(void)
{
    const unsigned char g[12] = {
        1, 2, 0x34, 0x12, 0x78, 0x56, 0x34, 0x12,
        0xef, 0xcd, 0xab, 0x90
    };
    unsigned char o[12] = {0};
    struct rec r = {9, 9, 9, 9, 9};
    struct rec before = r;

    if (dec(&r, g, sizeof g) != 0 || r.flags != UINT16_C(0x1234))
        return 1;
    if (enc(o, sizeof o, &r) != 0 || memcmp(o, g, sizeof g) != 0)
        return 1;

    r = before;
    if (dec(&r, g, 3) != EMSGSIZE || !same_rec(&r, &before))
        return 1;

    {
        unsigned char bad[12];
        memcpy(bad, g, sizeof bad);
        bad[0] = 2;
        r = before;
        if (dec(&r, bad, sizeof bad) != EINVAL || !same_rec(&r, &before))
            return 1;
    }

    puts("gate reference regressions: PASS");
    return 0;
}
