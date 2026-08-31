#include "format.h"
#include <stdio.h>
int format_score(char *buf, size_t cap, int score)
{
    int n = snprintf(buf, cap, "score=%d", score);
    return n >= 0 && (size_t)n < cap ? n : -1;
}
