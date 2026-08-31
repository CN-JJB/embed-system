#include "format.h"

#include <stdio.h>

int format_summary(char *buf, size_t cap, const char *name, int total, unsigned samples)
{
    int n = snprintf(buf, cap, "%s total=%d samples=%u", name, total, samples);
    if (n < 0 || (size_t)n >= cap) {
        return -1;
    }
    return n;
}
