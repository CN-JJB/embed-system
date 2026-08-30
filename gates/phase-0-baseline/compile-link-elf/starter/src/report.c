#include "format.h"
#include "metrics.h"
#include "report.h"

#include <stdio.h>

void report_print(void)
{
    char line[80];
    if (format_total(line, sizeof line, metrics_total(), dropped_count) < 0) {
        fputs("format error\n", stderr);
        return;
    }
    puts(line);
}
