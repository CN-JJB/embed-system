#include "shared_stats.h"
#include <assert.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUM_WORKERS 4
#define ADDS_PER_WORKER 2500

struct worker_arg {
    struct shared_stats *s;
    int worker_id;
};

static void *worker_thread(void *arg) {
    struct worker_arg *w = (struct worker_arg *)arg;
    for (int i = 1; i <= ADDS_PER_WORKER; i++) {
        int32_t val = (w->worker_id % 2 == 0) ? i : -i;
        int rc = stats_add(w->s, val);
        assert(rc == 0);
    }
    return NULL;
}

static void test_invalid_args_and_canary(void) {
    printf("test_invalid_args_and_canary... ");
    assert(stats_init(NULL) == -1);
    assert(stats_add(NULL, 10) == -1);
    assert(stats_destroy(NULL) == -1);

    struct stats_snapshot canary;
    memset(&canary, 0x5A, sizeof(canary));
    assert(stats_snapshot(NULL, &canary) == -1);
    /* Verify canary was not touched (no partial publish on failure) */
    unsigned char *p = (unsigned char *)&canary;
    for (size_t i = 0; i < sizeof(canary); i++) {
        assert(p[i] == 0x5A);
    }

    struct shared_stats s;
    assert(stats_init(&s) == 0);
    assert(stats_snapshot(&s, NULL) == -1);
    assert(stats_destroy(&s) == 0);
    printf("OK\n");
}

static void test_first_value_initializes(void) {
    printf("test_first_value_initializes... ");
    struct shared_stats s;
    assert(stats_init(&s) == 0);

    struct stats_snapshot snap;
    assert(stats_snapshot(&s, &snap) == 0);
    assert(snap.count == 0);
    assert(snap.sum == 0);
    assert(snap.initialized == 0);

    /* First value initializes min and max */
    assert(stats_add(&s, -42) == 0);
    assert(stats_snapshot(&s, &snap) == 0);
    assert(snap.count == 1);
    assert(snap.sum == -42);
    assert(snap.min == -42);
    assert(snap.max == -42);
    assert(snap.initialized == 1);

    assert(stats_destroy(&s) == 0);
    printf("OK\n");
}

static void test_multiple_updates_coherent(void) {
    printf("test_multiple_updates_coherent... ");
    struct shared_stats s;
    assert(stats_init(&s) == 0);

    int32_t values[] = { 100, -50, 25, -200, 300 };
    for (size_t i = 0; i < sizeof(values)/sizeof(values[0]); i++) {
        assert(stats_add(&s, values[i]) == 0);
    }

    struct stats_snapshot snap;
    assert(stats_snapshot(&s, &snap) == 0);
    assert(snap.count == 5);
    assert(snap.sum == 175);
    assert(snap.min == -200);
    assert(snap.max == 300);
    assert(snap.initialized == 1);

    assert(stats_destroy(&s) == 0);
    printf("OK\n");
}

static void test_sum_overflow_policy(void) {
    printf("test_sum_overflow_policy... ");
    struct shared_stats s;
    assert(stats_init(&s) == 0);

    assert(stats_add(&s, 100) == 0);

    /* Force internal sum near INT64_MAX to test overflow policy */
    pthread_mutex_lock(&s.mutex);
    s.sum = INT64_MAX - 50;
    s.count = 1;
    pthread_mutex_unlock(&s.mutex);

    /* Adding 100 would overflow int64_t */
    int rc = stats_add(&s, 100);
    assert(rc == -1);

    /* Verify state was NOT corrupted by failing operation */
    struct stats_snapshot snap;
    assert(stats_snapshot(&s, &snap) == 0);
    assert(snap.count == 1);
    assert(snap.sum == INT64_MAX - 50);

    /* Force internal sum near INT64_MIN to test underflow policy */
    pthread_mutex_lock(&s.mutex);
    s.sum = INT64_MIN + 50;
    pthread_mutex_unlock(&s.mutex);

    /* Adding -100 would underflow int64_t */
    rc = stats_add(&s, -100);
    assert(rc == -1);

    assert(stats_snapshot(&s, &snap) == 0);
    assert(snap.count == 1);
    assert(snap.sum == INT64_MIN + 50);

    assert(stats_destroy(&s) == 0);
    printf("OK\n");
}

static void test_concurrent_stress_and_invariant(void) {
    printf("test_concurrent_stress_and_invariant... ");
    struct shared_stats s;
    assert(stats_init(&s) == 0);

    pthread_t threads[NUM_WORKERS];
    struct worker_arg args[NUM_WORKERS];

    for (int i = 0; i < NUM_WORKERS; i++) {
        args[i].s = &s;
        args[i].worker_id = i;
        assert(pthread_create(&threads[i], NULL, worker_thread, &args[i]) == 0);
    }

    /* Concurrent snapshot checks invariant repeatedly */
    for (int i = 0; i < 500; i++) {
        struct stats_snapshot snap;
        assert(stats_snapshot(&s, &snap) == 0);
        if (snap.initialized) {
            assert(snap.min <= snap.max);
            assert(snap.count > 0);
        }
    }

    for (int i = 0; i < NUM_WORKERS; i++) {
        assert(pthread_join(threads[i], NULL) == 0);
    }

    struct stats_snapshot final_snap;
    assert(stats_snapshot(&s, &final_snap) == 0);
    assert(final_snap.count == NUM_WORKERS * ADDS_PER_WORKER);
    assert(final_snap.initialized == 1);
    /* Even workers add +1..N, odd workers add -1..N, so net sum is 0 */
    assert(final_snap.sum == 0);
    assert(final_snap.min == -ADDS_PER_WORKER);
    assert(final_snap.max == ADDS_PER_WORKER);

    assert(stats_destroy(&s) == 0);
    printf("OK\n");
}

int main(void) {
    printf("=== M09 Challenge Test Suite ===\n");
    test_invalid_args_and_canary();
    test_first_value_initializes();
    test_multiple_updates_coherent();
    test_sum_overflow_policy();
    test_concurrent_stress_and_invariant();
    printf("=== All Challenge Tests PASSED ===\n");
    return 0;
}
