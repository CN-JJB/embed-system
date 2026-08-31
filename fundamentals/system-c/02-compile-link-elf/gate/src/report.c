#include "format.h"
#include "report.h"
#include "sampler.h"
#include <stdio.h>
void report_emit(void)
{
    char buf[80];
    int scaled = sampler_scale(sampler_total());
    if (format_line(buf, sizeof buf, scaled, sample_dropped) >= 0) puts(buf);
}
