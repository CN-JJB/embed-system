#ifndef REGISTRY_H
#define REGISTRY_H
extern int registry_samples;
void registry_add(int value);
int registry_limit(void);
int registry_total(void);
#endif
