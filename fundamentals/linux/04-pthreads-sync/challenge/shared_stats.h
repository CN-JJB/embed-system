#ifndef SHARED_STATS_H
#define SHARED_STATS_H

#include <pthread.h>
#include <stdint.h>

/*
 * Coherent snapshot of shared statistics.
 * Copied atomically under mutex protection; callers read this snapshot
 * without holding internal locks.
 */
struct stats_snapshot {
    uint64_t count;
    int64_t sum;
    int32_t min;
    int32_t max;
    int initialized;
};

/*
 * Shared statistics accumulator protected by an internal mutex.
 * The mutex protects the multi-field invariant:
 * - count == 0 <=> initialized == 0
 * - count > 0  <=> initialized == 1 && min <= max
 * - sum is the exact arithmetic sum of all added values (overflow checked).
 */
struct shared_stats {
    uint64_t count;
    int64_t sum;
    int32_t min;
    int32_t max;
    int initialized;
    pthread_mutex_t mutex;
};

/*
 * Initializes the statistics structure and its internal mutex.
 * Returns 0 on success, -1 on invalid argument or initialization failure.
 */
int stats_init(struct shared_stats *s);

/*
 * Atomically updates count, sum, min, and max with the given value.
 * First value initializes min and max.
 * If adding value would cause 64-bit signed integer overflow/underflow,
 * returns -1 without modifying any fields in s.
 * Returns 0 on success, -1 on invalid argument, overflow, or lock error.
 */
int stats_add(struct shared_stats *s, int32_t value);

/*
 * Atomically captures a snapshot of current statistics into *out.
 * If s or out is NULL, returns -1 and leaves *out untouched (no partial publish).
 * Returns 0 on success, -1 on error.
 */
int stats_snapshot(struct shared_stats *s, struct stats_snapshot *out);

/*
 * Destroys the internal mutex.
 * Must be called only after all worker threads have completed and joined.
 * Returns 0 on success, -1 on invalid argument or destroy failure.
 */
int stats_destroy(struct shared_stats *s);

#endif /* SHARED_STATS_H */
