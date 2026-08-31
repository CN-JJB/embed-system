#include "registry.h"
int registry_samples;
static int total;
int registry_limit(void) { return 64; } /* wrong linkage for header contract */
void registry_add(int value)
{
    if (registry_samples < registry_limit()) { total += value; ++registry_samples; }
}
int registry_total(void) { return total; }
