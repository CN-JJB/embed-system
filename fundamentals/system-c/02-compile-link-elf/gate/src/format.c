#include "format.h"
#include <stdio.h>
int format_line(char *buf, size_t cap, int total, int dropped)
{
    int n = snprintf(buf, cap, "gate total=%d dropped=%d", total, dropped);
    return n >= 0 && (size_t)n < cap ? n : -1;
}
