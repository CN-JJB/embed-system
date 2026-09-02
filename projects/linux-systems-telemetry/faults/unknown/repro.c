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
 * Reproduces the intermittent shutdown hang symptom under a bounded harness.
 */

struct service_queue {
    struct telemetry_record ring[8];
    size_t count;
    int closed;
    int waiter_count;
    pthread_mutex_t lock;
    pthread_cond_t not_empty;
    pthread_cond_t waiter_ready;
};

static struct service_queue g_queue;

static void watchdog_handler(int sig) {
    (void)sig;
    const char msg[] = "\n>>> TIMEOUT: Telemetry service shutdown hung! Process failed to exit within 3s. <<<\n";
    write(STDOUT_FILENO, msg, sizeof(msg) - 1);
    _exit(2);
}

static void queue_init(struct service_queue *q) {
    memset(q, 0, sizeof(*q));
    pthread_mutex_init(&q->lock, NULL);
    pthread_cond_init(&q->not_empty, NULL);
    pthread_cond_init(&q->waiter_ready, NULL);
}

static int queue_pop(struct service_queue *q, struct telemetry_record *out) {
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

static void queue_close(struct service_queue *q) {
    pthread_mutex_lock(&q->lock);
    q->closed = 1;
    pthread_mutex_unlock(&q->lock);
}

static void *consumer_worker(void *arg) {
    (void)arg;
    struct telemetry_record rec;
    while (queue_pop(&g_queue, &rec)) {
        /* Process incoming telemetry record */
    }
    return NULL;
}

int main(void) {
    printf("=== Unknown Fault Reproduction Harness ===\n");
    queue_init(&g_queue);

    /* Arm 3-second watchdog timer to bound execution */
    signal(SIGALRM, watchdog_handler);
    alarm(3);

    pthread_t worker;
    pthread_create(&worker, NULL, consumer_worker, NULL);

    /* Coordination: wait until worker has entered polling state */
    pthread_mutex_lock(&g_queue.lock);
    while (g_queue.waiter_count == 0) {
        pthread_cond_wait(&g_queue.waiter_ready, &g_queue.lock);
    }
    pthread_mutex_unlock(&g_queue.lock);

    printf("[main] Ingestion worker started...\n");
    printf("[main] Initiating service shutdown...\n");
    fflush(stdout);

    /* Trigger shutdown sequence */
    queue_close(&g_queue);

    printf("[main] Waiting for worker thread to join...\n");
    fflush(stdout);

    /* If shutdown hangs, watchdog fires after 3 seconds */
    pthread_join(worker, NULL);

    alarm(0);
    printf("[main] Worker joined unexpectedly.\n");
    return 0;
}
