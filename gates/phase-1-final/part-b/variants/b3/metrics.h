#ifndef B3_METRICS_H
#define B3_METRICS_H

#include <stdint.h>
#include <pthread.h>

#define B3_TOTAL_BALANCE 1000000LL

struct metrics_tracker {
    pthread_mutex_t lock;
    int64_t pool_a;
    int64_t pool_b;
};

void metrics_init(struct metrics_tracker *mt);
void metrics_transfer(struct metrics_tracker *mt, int64_t amount);
void metrics_read_snapshot(struct metrics_tracker *mt, int64_t *out_a, int64_t *out_b);
void metrics_destroy(struct metrics_tracker *mt);

#endif /* B3_METRICS_H */
