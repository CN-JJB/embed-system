#include "shared_stats.h"
#include <limits.h>
#include <string.h>

/*
 * Reviewer reference implementation of thread-safe shared statistics.
 * Invariant:
 *   Under s->mutex:
 *     - count == 0 <=> initialized == 0
 *     - count > 0  <=> initialized == 1 && min <= max
 *     - sum is exact sum of accepted updates
 * No partial publish on snapshot failure; overflow rejected cleanly.
 */

int stats_init(struct shared_stats *s) {
    if (!s) {
        return -1;
    }
    memset(s, 0, sizeof(*s));
    if (pthread_mutex_init(&s->mutex, NULL) != 0) {
        return -1;
    }
    return 0;
}

int stats_add(struct shared_stats *s, int32_t value) {
    if (!s) {
        return -1;
    }
    if (pthread_mutex_lock(&s->mutex) != 0) {
        return -1;
    }

    /* Overflow check before mutating sum or count */
    if ((value > 0 && s->sum > INT64_MAX - value) ||
        (value < 0 && s->sum < INT64_MIN - value)) {
        pthread_mutex_unlock(&s->mutex);
        return -1;
    }

    s->sum += value;
    s->count++;

    if (!s->initialized) {
        s->min = value;
        s->max = value;
        s->initialized = 1;
    } else {
        if (value < s->min) {
            s->min = value;
        }
        if (value > s->max) {
            s->max = value;
        }
    }

    if (pthread_mutex_unlock(&s->mutex) != 0) {
        return -1;
    }
    return 0;
}

int stats_snapshot(struct shared_stats *s, struct stats_snapshot *out) {
    if (!s || !out) {
        return -1;
    }

    struct stats_snapshot tmp;
    if (pthread_mutex_lock(&s->mutex) != 0) {
        return -1;
    }

    tmp.count = s->count;
    tmp.sum = s->sum;
    tmp.min = s->min;
    tmp.max = s->max;
    tmp.initialized = s->initialized;

    if (pthread_mutex_unlock(&s->mutex) != 0) {
        return -1;
    }

    /* Publish only after lock is released and complete snapshot is captured */
    *out = tmp;
    return 0;
}

int stats_destroy(struct shared_stats *s) {
    if (!s) {
        return -1;
    }
    if (pthread_mutex_destroy(&s->mutex) != 0) {
        return -1;
    }
    return 0;
}
