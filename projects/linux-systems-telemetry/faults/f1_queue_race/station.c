#define _DEFAULT_SOURCE
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <assert.h>
#include "telemetry.h"

/*
 * M10 Fault Station F1: Queue Field Race
 *
 * Seeded bug:
 * In this modified queue push, the shared queue field `q->count` is updated
 * OUTSIDE the mutex lock:
 *   pthread_mutex_unlock(&q->lock);
 *   q->count++; // SEEDED RACE
 *
 * Under concurrent producers, data races occur on `q->count`, causing lost updates
 * and violating the queue invariant:
 *   q->count == number of valid elements stored in ring.
 */

#define TEST_CAPACITY 100000
#define ITEMS_PER_PRODUCER 25000

struct race_queue {
    struct telemetry_record ring[TEST_CAPACITY];
    size_t head;
    size_t count; /* Shared field subjected to unsynchronized concurrent access */
    pthread_mutex_t lock;
};

static struct race_queue g_queue;

static void queue_init(struct race_queue *q) {
    memset(q, 0, sizeof(*q));
    pthread_mutex_init(&q->lock, NULL);
}

static void queue_push_racy(struct race_queue *q, const struct telemetry_record *rec) {
    pthread_mutex_lock(&q->lock);
    size_t idx = q->head;
    q->ring[idx] = *rec;
    q->head = (q->head + 1) % TEST_CAPACITY;
    pthread_mutex_unlock(&q->lock);

    /* SEEDED BUG: Shared count updated outside mutex protection */
    q->count++;
}

static void *producer_worker(void *arg) {
    (void)arg;
    struct telemetry_record r = { .version = 1, .kind = 1, .flags = 0, .value = 10, .sequence = 1 };
    for (int i = 0; i < ITEMS_PER_PRODUCER; i++) {
        queue_push_racy(&g_queue, &r);
    }
    return NULL;
}

int main(void) {
    printf("=== M10 Fault Station F1: Queue Field Race ===\n");
    queue_init(&g_queue);

    pthread_t p1, p2;
    pthread_create(&p1, NULL, producer_worker, NULL);
    pthread_create(&p2, NULL, producer_worker, NULL);

    pthread_join(p1, NULL);
    pthread_join(p2, NULL);

    size_t expected = ITEMS_PER_PRODUCER * 2;
    printf("Finished: total pushed=%zu, recorded queue.count=%zu\n",
           expected, g_queue.count);

    if (g_queue.count != expected) {
        printf(">>> F1 REPRODUCED: Unsynchronized queue count corrupted! (lost %zu updates) <<<\n",
               expected - g_queue.count);
        return 1;
    } else {
        printf("Race did not manifest numerically in this run; run with TSan or repeat.\n");
        return 0;
    }
}
