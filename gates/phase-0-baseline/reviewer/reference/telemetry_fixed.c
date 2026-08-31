#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct decoded_header {
    uint8_t type;
    uint32_t sequence;
    uint16_t sample_count;
};

static unsigned reports_created;

static int make_label(char *dst, size_t cap, unsigned id)
{
    if (dst == NULL || cap == 0) {
        return EINVAL;
    }

    int n = snprintf(dst, cap, "sensor-%u", id);
    if (n < 0 || (size_t)n >= cap) {
        return ENOSPC;
    }
    return 0;
}

static size_t copy_samples(int16_t *dst, size_t capacity,
                           const int16_t *src, size_t count)
{
    if (count > capacity) {
        count = capacity;
    }
    memcpy(dst, src, count * sizeof src[0]);
    return count;
}

static int32_t sum_samples(const int16_t *samples, size_t count)
{
    int32_t total = 0;
    for (size_t i = 0; i < count; ++i) {
        total += samples[i];
    }
    return total;
}

static int scale_raw(int32_t raw, int32_t *out)
{
    if (out == NULL) {
        return EINVAL;
    }
    if (raw > INT32_MAX / 16 || raw < INT32_MIN / 16) {
        return ERANGE;
    }
    *out = raw * 16;
    return 0;
}

static struct decoded_header decode_header_le(const uint8_t wire[7])
{
    struct decoded_header h = {
        .type = wire[0],
        .sequence = (uint32_t)wire[1]
                  | ((uint32_t)wire[2] << 8)
                  | ((uint32_t)wire[3] << 16)
                  | ((uint32_t)wire[4] << 24),
        .sample_count = (uint16_t)((uint16_t)wire[5]
                      | ((uint16_t)wire[6] << 8)),
    };
    return h;
}

static char *make_summary(const char *label, int32_t sum)
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
    const uint8_t wire[7] = {0x02, 0x78, 0x56, 0x34, 0x12, 0x04, 0x00};
    const int16_t input[] = {120, -3, 40, 7};
    int16_t copied[4] = {0};
    char label[24];

    if (make_label(label, sizeof label, 7) != 0) {
        return 1;
    }

    struct decoded_header header = decode_header_le(wire);
    size_t n = copy_samples(copied, sizeof copied / sizeof copied[0],
                            input, sizeof input / sizeof input[0]);
    int32_t sum = sum_samples(copied, n);
    int32_t scaled = 0;
    if (scale_raw(input[1], &scaled) != 0) {
        return 1;
    }

    char *summary = make_summary(label, sum);
    if (summary == NULL) {
        fputs("summary allocation failed\n", stderr);
        return 1;
    }

    printf("label=%s\n", label);
    printf("header: type=%u sequence=%lu count=%u\n",
           (unsigned)header.type,
           (unsigned long)header.sequence,
           (unsigned)header.sample_count);
    printf("copied=%zu sum=%ld scaled=%ld\n",
           n, (long)sum, (long)scaled);
    puts(summary);

    free(summary);
    return 0;
}
