#ifndef SAMPLER_H
#define SAMPLER_H
extern int sample_limit;
extern int sample_dropped;
void sampler_record(int value);
int sampler_total(void);
int sampler_scale(int value);
#endif
