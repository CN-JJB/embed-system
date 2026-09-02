#define _DEFAULT_SOURCE
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <signal.h>
#include "telemetry.h"

/*
 * Unknown Fault Bounded Reproduction Fixture
 *
 * Implements a broken queue shutdown sequence and bounded harness.
 */

struct broken_queue {
    struct telemetry_record ring[8];
    size_t count;
    int closed;
    int waiter_count;
    pthread_mutex_t lock;
    pthread_cond_t not_empty;
    pthread_cond_t waiter_ready;
};

static struct broken_queue g_bq;

static void watchdog_handler(int sig) {
    (void)sig;
    const char msg[] = "\n>>> UNKNOWN FAULT REPRODUCED: Consumer thread remained blocked after queue close! <<<\n";
    write(STDOUT_FILENO, msg, sizeof(msg) - 1);
    _exit(2);
}

static void broken_queue_init(struct broken_queue *q) {
    memset(q, 0, sizeof(*q));
    pthread_mutex_init(&q->lock, NULL);
    pthread_cond_init(&q->not_empty, NULL);
    pthread_cond_init(&q->waiter_ready, NULL);
}

static int broken_queue_pop(struct broken_queue *q, struct telemetry_record *out) {
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

static void broken_queue_close(struct broken_queue *q) {
    pthread_mutex_lock(&q->lock);
    /* HIDDEN SEED: Marks closed, but omits waking sleeping waiters */
    q->closed = 1;
    pthread_mutex_unlock(&q->lock);
}

static void *consumer_worker(void *arg) {
    (void)arg;
    struct telemetry_record rec;
    /* This will block because queue is empty and close fails to wake it */
    while (broken_queue_pop(&g_bq, &rec)) {
        /* Process record */
    }
    return NULL;
}

int main(void) {
    printf("=== Unknown Fault Reproduction Harness ===\n");
    broken_queue_init(&g_bq);

    /* Arm 3-second watchdog timer to bound execution */
    signal(SIGALRM, watchdog_handler);
    alarm(3);

    pthread_t worker;
    pthread_create(&worker, NULL, consumer_worker, NULL);

    /* Deterministic coordination: wait until worker has reached wait state */
    pthread_mutex_lock(&g_bq.lock);
    while (g_bq.waiter_count == 0) {
        pthread_cond_wait(&g_bq.waiter_ready, &g_bq.lock);
    }
    pthread_mutex_unlock(&g_bq.lock);

    printf("[main] Worker started and waiting on queue...\n");
    printf("[main] Initiating queue close...\n");
    fflush(stdout);

    /* Initiate broken shutdown */
    broken_queue_close(&g_bq);

    printf("[main] Waiting for worker thread to join...\n");
    fflush(stdout);

    /* Blocks here indefinitely until watchdog fires */
    pthread_join(worker, NULL);

    alarm(0);
    printf("[main] Worker joined unexpectedly.\n");
    return 0;
}
