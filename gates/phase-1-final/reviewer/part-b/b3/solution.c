#include "../../../part-b/variants/b3/metrics.h"
#include <string.h>

void metrics_init(struct metrics_tracker *mt) {
    memset(mt, 0, sizeof(*mt));
    pthread_mutex_init(&mt->lock, NULL);
    mt->pool_a = B3_TOTAL_BALANCE;
    mt->pool_b = 0;
}

void metrics_transfer(struct metrics_tracker *mt, int64_t amount) {
    pthread_mutex_lock(&mt->lock);
    mt->pool_a -= amount;
    mt->pool_b += amount;
    pthread_mutex_unlock(&mt->lock);
}

void metrics_read_snapshot(struct metrics_tracker *mt, int64_t *out_a, int64_t *out_b) {
    pthread_mutex_lock(&mt->lock);
    if (out_a) *out_a = mt->pool_a;
    if (out_b) *out_b = mt->pool_b;
    pthread_mutex_unlock(&mt->lock);
}

void metrics_destroy(struct metrics_tracker *mt) {
    pthread_mutex_destroy(&mt->lock);
}
