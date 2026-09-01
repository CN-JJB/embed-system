#include "stats.h"
#include <limits.h>
void telemetry_stats_init(struct telemetry_stats *s){s->count=0;s->sum=0;s->min=0;s->max=0;s->initialized=0;s->overflowed=0;}
int telemetry_stats_add(struct telemetry_stats *s,const struct telemetry_record *r){int64_t v=r->value;if((v>0&&s->sum>INT64_MAX-v)||(v<0&&s->sum<INT64_MIN-v)){s->overflowed=1;return -1;}s->sum+=v;s->count++;if(!s->initialized){s->min=r->value;s->max=r->value;s->initialized=1;}else{if(r->value<s->min)s->min=r->value;if(r->value>s->max)s->max=r->value;}return 0;}
double telemetry_stats_mean(const struct telemetry_stats *s){return s->count?((double)s->sum/(double)s->count):0.0;}
