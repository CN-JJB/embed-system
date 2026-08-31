#include "stats.h"

unsigned stats_total_samples;
static int running_total;

void stats_update(int value)
{
    running_total += value;
    ++stats_total_samples;
}

int stats_total(void)
{
    return running_total;
}
