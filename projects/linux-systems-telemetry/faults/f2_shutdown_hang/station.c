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
 * M10 Fault Station F2: Shutdown Hang
 *
 * Seeded bug:
 * Worker is blocked in queue_pop waiting on condvar not_empty.
 * The producer closes the queue: sets closed = 1, but OMITS the broadcast.
 * As a result, the worker never wakes up to evaluate the terminal predicate
 * (closed && count == 0), causing an indefinite shutdown hang.
 */

struct test_queue {
    struct telemetry_record ring[4];
    size_t count;
    int closed;
    pthread_mutex_t lock;
    pthread_cond_t not_empty;
};

static struct test_queue g_queue;

static void watchdog(int sig) {
    (void)sig;
    const char msg[] = ">>> F2 REPRODUCED: Shutdown hang! Worker thread remained blocked after close. <<<\n"
                       "Root cause: Predicate changed to (closed=1), but sleeper was not signaled to re-evaluate.\n";
    write(STDOUT_FILENO, msg, sizeof(msg) - 1);
    _exit(2);
}

static void *worker_func(void *arg) {
    (void)arg;
    pthread_mutex_lock(&g_queue.lock);
    while (g_queue.count == 0 && !g_queue.closed) {
        pthread_cond_wait(&g_queue.not_empty, &g_queue.lock);
    }
    pthread_mutex_unlock(&g_queue.lock);
    return NULL;
}

int main(void) {
    printf("=== M10 Fault Station F2: Shutdown Hang ===\n");
    memset(&g_queue, 0, sizeof(g_queue));
    pthread_mutex_init(&g_queue.lock, NULL);
    pthread_cond_init(&g_queue.not_empty, NULL);

    /* Arm 2-second watchdog */
    signal(SIGALRM, watchdog);
    alarm(2);

    pthread_t w;
    pthread_create(&w, NULL, worker_func, NULL);

    /* Allow worker to block on condvar */
    usleep(50000);

    /* SEEDED BUG: Set closed under lock, but OMIT broadcast */
    pthread_mutex_lock(&g_queue.lock);
    g_queue.closed = 1;
    /* OMITTED: pthread_cond_broadcast(&g_queue.not_empty); */
    pthread_mutex_unlock(&g_queue.lock);

    printf("Main thread closed queue; waiting for worker to join...\n");
    fflush(stdout);

    pthread_join(w, NULL);

    /* If reached here without hang, disarm alarm */
    alarm(0);
    printf("Worker joined cleanly.\n");
    return 0;
}
