#include <stdint.h>
#include <stdio.h>
#include <string.h>

struct record {
    char payload[16];
    uint32_t guard;
};

static void copy_payload(struct record *r, const char *input)
{
    size_t n = strlen(input);
    for (size_t i = 0; i <= n; ++i) {
        r->payload[i] = input[i];
    }
}

static unsigned unrelated_work(const char *s)
{
    unsigned x = 0;
    for (; *s; ++s) {
        x = (x * 33u) ^ (unsigned char)*s;
    }
    return x;
}

int main(void)
{
    struct record r = {{0}, 0xdeadbeefU};
    const char *input = "0123456789ABCDEF"; /* 16 visible bytes */

    copy_payload(&r, input);
    printf("work=%u\n", unrelated_work("later-stage"));

    if (r.guard != 0xdeadbeefU) {
        fprintf(stderr, "record guard corrupted: 0x%08x\n", r.guard);
        return 1;
    }

    puts("record valid");
    return 0;
}
