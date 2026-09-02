#define _DEFAULT_SOURCE
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <assert.h>
#include "telemetry.h"

/*
 * Reviewer Reference Solution: Unknown Fault Regression
 *
 * Proves the full shutdown lifecycle:
 * 1. Blocked empty consumer is awakened by queue_close.
 * 2. Consumer re-evaluates predicate, observes (closed && count == 0).
 * 3. Consumer thread terminates.
 * 4. pthread_join succeeds without blocking.
 * 5. Synchronization objects are cleanly destroyed.
 * 6. Executed 100 times without race or failure.
 */

#define REGRESSION_CYCLES 100

struct fixed_queue {
    struct telemetry_record ring[8];
    size_t count;
    int closed;
    int waiter_count;
    pthread_mutex_t lock;
    pthread_cond_t not_empty;
    pthread_cond_t waiter_ready;
};

static void fixed_queue_init(struct fixed_queue *q) {
    memset(q, 0, sizeof(*q));
    assert(pthread_mutex_init(&q->lock, NULL) == 0);
    assert(pthread_cond_init(&q->not_empty, NULL) == 0);
    assert(pthread_cond_init(&q->waiter_ready, NULL) == 0);
}

static int fixed_queue_pop(struct fixed_queue *q, struct telemetry_record *out) {
    (void)out;
    pthread_mutex_lock(&q->lock);
    q->waiter_count++;
    pthread_cond_signal(&q->waiter_ready);

    while (q->count == 0 && !q->closed) {
        pthread_cond_wait(&q->not_empty, &q->lock);
    }

    q->waiter_count--;
    int ok = 0;
    if (q->count > 0) {
        ok = 1;
        q->count--;
    }
    pthread_mutex_unlock(&q->lock);
    return ok;
}

static void fixed_queue_close(struct fixed_queue *q) {
    pthread_mutex_lock(&q->lock);
    q->closed = 1;
    /* CORRECT FIX: Broadcast to wake any sleeping consumers */
    pthread_cond_broadcast(&q->not_empty);
    pthread_mutex_unlock(&q->lock);
}

static void fixed_queue_destroy(struct fixed_queue *q) {
    assert(pthread_mutex_destroy(&q->lock) == 0);
    assert(pthread_cond_destroy(&q->not_empty) == 0);
    assert(pthread_cond_destroy(&q->waiter_ready) == 0);
}

static void *fixed_consumer_worker(void *arg) {
    struct fixed_queue *q = (struct fixed_queue *)arg;
    struct telemetry_record rec;
    while (fixed_queue_pop(q, &rec)) {
        /* Process records */
    }
    return NULL;
}

int main(void) {
    printf("=== Running Unknown Fault Fixed Regression (%d cycles) ===\n", REGRESSION_CYCLES);

    for (int cycle = 1; cycle <= REGRESSION_CYCLES; cycle++) {
        struct fixed_queue q;
        fixed_queue_init(&q);

        pthread_t worker;
        assert(pthread_create(&worker, NULL, fixed_consumer_worker, &q) == 0);

        /* Deterministic coordination: wait until worker is blocked on condvar */
        pthread_mutex_lock(&q.lock);
        while (q.waiter_count == 0) {
            pthread_cond_wait(&q.waiter_ready, &q.lock);
        }
        pthread_mutex_unlock(&q.lock);

        /* Close queue with broadcast */
        fixed_queue_close(&q);

        /* Join worker: MUST return promptly without hang */
        assert(pthread_join(worker, NULL) == 0);

        /* Destroy synchronization objects: MUST succeed */
        fixed_queue_destroy(&q);
    }

    printf(">>> SUCCESS: 100/100 shutdown cycles completed cleanly (close -> wake -> exit -> join -> destroy) <<<\n");
    return 0;
}
