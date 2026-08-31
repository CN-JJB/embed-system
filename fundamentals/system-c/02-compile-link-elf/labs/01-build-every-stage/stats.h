#ifndef STATS_H
#define STATS_H

extern unsigned stats_total_samples;
void stats_update(int value);
int stats_total(void);

#endif
