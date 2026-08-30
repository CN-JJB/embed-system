#ifndef METRICS_H
#define METRICS_H

/* Deliberately problematic header: investigate linkage and ownership of this definition. */
int sample_count = 1;

extern int dropped_count;

void metrics_add(int value);
int metrics_total(void);

#endif
