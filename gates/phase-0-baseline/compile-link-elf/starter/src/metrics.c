#include "metrics.h"

int dropped_count;
static int running_total;

void metrics_add(int value)
{
    running_total += value;
    ++sample_count;
}

int metrics_total(void)
{
    return running_total + sample_count;
}
