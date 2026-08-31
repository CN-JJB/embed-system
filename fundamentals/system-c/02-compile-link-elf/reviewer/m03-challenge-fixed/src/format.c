#include "format.h"
#include <stdio.h>
int report_width = 48;
int format_report(char *buf, size_t cap, int total, int samples)
{
    int n = snprintf(buf, cap, "total=%d samples=%d width=%d", total, samples, report_width);
    return n >= 0 && (size_t)n < cap ? n : -1;
}
