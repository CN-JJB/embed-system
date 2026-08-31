#include "stats.h"
int main(void)
{
    stats_update(11);
    return stats_total() == 11 ? 0 : 1;
}
