#include "format.h"
#include "stats.h"
#include <stdio.h>
int main(void)
{
    char buf[32];
    int score = stats_score(40);
    if (format_score(buf, sizeof buf, score) < 0) return 1;
    puts(buf);
    return 0;
}
