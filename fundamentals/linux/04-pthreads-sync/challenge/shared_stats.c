#include "shared_stats.h"
#include <string.h>

/*
 * LEARNER STARTER FIXTURE — Shared Statistics Challenge
 *
 * Requirements:
 * 1. The internal mutex must protect {count, sum, min, max, initialized} as one
 *    coherent invariant.
 * 2. First added value initializes min and max (initialized becomes 1).
 * 3. Adding a value must check for 64-bit sum overflow/underflow without state mutation.
 * 4. stats_snapshot must capture a coherent view under lock and write to *out only
 *    upon full success (no partial publication on error).
 * 5. stats_destroy must cleanly destroy the mutex after caller threads have joined.
 *
 * Current state: SKELETON / INCOMPLETE.
 * Must be implemented by learner to pass challenge regression tests.
 */

int stats_init(struct shared_stats *s) {
    if (!s) {
        return -1;
    }
    memset(s, 0, sizeof(*s));
    /* LEARNER TODO: Initialize internal mutex and verify return status */
    return -1;
}

int stats_add(struct shared_stats *s, int32_t value) {
    if (!s) {
        return -1;
    }
    (void)value;
    /*
     * LEARNER TODO:
     * - Acquire internal mutex.
     * - Check for 64-bit signed integer overflow (INT64_MAX) or underflow (INT64_MIN).
     * - If overflow would occur, unlock and return -1 without modifying state.
     * - Update count, sum, min, max, and initialized flag.
     * - Release mutex and return 0 on success.
     */
    return -1;
}

int stats_snapshot(struct shared_stats *s, struct stats_snapshot *out) {
    if (!s || !out) {
        return -1;
    }
    /*
     * LEARNER TODO:
     * - Acquire internal mutex.
     * - Copy current statistics atomically to temporary snapshot.
     * - Release mutex.
     * - Write temporary snapshot to *out only after successful capture.
     */
    return -1;
}

int stats_destroy(struct shared_stats *s) {
    if (!s) {
        return -1;
    }
    /* LEARNER TODO: Destroy internal mutex and return status */
    return -1;
}
