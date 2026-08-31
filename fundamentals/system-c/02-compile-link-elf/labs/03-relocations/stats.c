#include "stats.h"
static int total;
void stats_update(int value) { total += value; }
int stats_total(void) { return total; }
