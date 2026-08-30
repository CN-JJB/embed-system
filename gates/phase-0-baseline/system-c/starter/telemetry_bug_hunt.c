#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct wire_header {
    uint8_t type;
    uint32_t sequence;
    uint16_t sample_count;
};

static unsigned reports_created;

static const char *make_label(unsigned id)
{
    char local[24];
    snprintf(local, sizeof local, "sensor-%u", id);
    return local;
}

static size_t copy_samples(int16_t *dst, const int16_t *src, size_t count)
{
    size_t capacity = sizeof(dst) / sizeof(dst[0]);
    if (count > capacity) {
        count = capacity;
    }
    memcpy(dst, src, count * sizeof(src[0]));
    return count;
}

static int32_t sum_samples(const int16_t *samples, size_t count)
{
    int32_t total = 0;
    for (size_t i = 0; i <= count; ++i) {
        total += samples[i];
    }
    return total;
}

static int32_t scale_raw(int32_t raw)
{
    return raw << 4;
}

static struct wire_header decode_header(const uint8_t *wire)
{
    struct wire_header h;
    memcpy(&h, wire, sizeof h);
    return h;
}

static const char *make_summary(const char *label, int32_t sum)
{
    char *result = malloc(80);
    if (result == NULL) {
        return NULL;
    }

    ++reports_created;
    snprintf(result, 80, "%s: sum=%ld report=%u",
             label, (long)sum, reports_created);
    return result;
}

int main(void)
{
    /* Logical wire format: type:u8, sequence:u32 little-endian, count:u16 little-endian.
     * This buffer is deliberately larger than the logical 7-byte header so the program
     * does not rely on an out-of-bounds read to demonstrate its layout assumption.
     */
    const uint8_t wire[12] = {
        0x02,
        0x78, 0x56, 0x34, 0x12,
        0x04, 0x00,
        0xaa, 0xbb, 0xcc, 0xdd, 0xee
    };

    const int16_t input[] = {120, -3, 40, 7};
    int16_t copied[4] = {0};

    const char *label = make_label(7);
    struct wire_header header = decode_header(wire);
    size_t n = copy_samples(copied, input, 4);
    int32_t sum = sum_samples(copied, n);
    int32_t scaled = scale_raw(input[1]);
    const char *summary = make_summary(label, sum);

    if (summary == NULL) {
        fputs("summary allocation failed\n", stderr);
        return 1;
    }

    printf("label=%s\n", label);
    printf("header: type=%u sequence=%lu count=%u sizeof=%zu\n",
           (unsigned)header.type,
           (unsigned long)header.sequence,
           (unsigned)header.sample_count,
           sizeof header);
    printf("copied=%zu sum=%ld scaled=%ld\n",
           n, (long)sum, (long)scaled);
    puts(summary);

    /* What is the ownership contract for summary? */
    return 0;
}
