#ifndef STATS_H
#define STATS_H
#include <stdint.h>
#include "telemetry.h"
struct telemetry_stats { uint64_t count; int64_t sum; int32_t min,max; int initialized; int overflowed; };
void telemetry_stats_init(struct telemetry_stats *s);
int telemetry_stats_add(struct telemetry_stats *s,const struct telemetry_record *r);
double telemetry_stats_mean(const struct telemetry_stats *s);
#endif
