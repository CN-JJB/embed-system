#include "format.h"
#include "registry.h"
#include "report.h"
#include <stdio.h>
void report_emit(void)
{
    char buf[96];
    if (format_report(buf, sizeof buf, registry_total(), registry_samples) >= 0) puts(buf);
}
