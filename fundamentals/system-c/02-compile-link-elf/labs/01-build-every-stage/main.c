#include "format.h"
#include "stats.h"

#include <stdio.h>

int main(void)
{
    static int run_number = 1;
    const char *label = "translation-pipeline";
    char line[96];

    stats_update(4);
    stats_update(9);
    if (format_summary(line, sizeof line, label, stats_total(), stats_total_samples) < 0) {
        return 1;
    }

    printf("run=%d %s\n", run_number, line);
    return 0;
}
