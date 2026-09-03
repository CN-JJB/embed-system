#define _POSIX_C_SOURCE 200809L
#include "metrics.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <stdbool.h>

static struct metrics_tracker g_mt;
static pthread_mutex_t g_ctrl_lock = PTHREAD_MUTEX_INITIALIZER;
static bool g_running = true;
static bool g_violation_found = false;

static void timeout_handler(int sig) {
    (void)sig;
    const char msg[] = "\n>>> TIMEOUT: B3 harness exceeded safety watchdog timer! <<<\n";
    write(STDERR_FILENO, msg, sizeof(msg) - 1);
    _exit(2);
}

static bool is_running(void) {
    pthread_mutex_lock(&g_ctrl_lock);
    bool r = g_running;
    pthread_mutex_unlock(&g_ctrl_lock);
    return r;
}

static void stop_harness(bool violation) {
    pthread_mutex_lock(&g_ctrl_lock);
    g_running = false;
    if (violation) {
        g_violation_found = true;
    }
    pthread_mutex_unlock(&g_ctrl_lock);
}

static bool check_violation(void) {
    pthread_mutex_lock(&g_ctrl_lock);
    bool v = g_violation_found;
    pthread_mutex_unlock(&g_ctrl_lock);
    return v;
}

static void *worker_ab(void *arg) {
    (void)arg;
    for (int i = 0; i < 50000; i++) {
        if ((i % 64 == 0) && !is_running()) {
            break;
        }
        metrics_transfer(&g_mt, 10);
        metrics_transfer(&g_mt, -10);
    }
    return NULL;
}

static void *auditor(void *arg) {
    (void)arg;
    while (is_running()) {
        int64_t a = 0, b = 0;
        metrics_read_snapshot(&g_mt, &a, &b);
        if (a + b != B3_TOTAL_BALANCE) {
            stop_harness(true);
            break;
        }
    }
    return NULL;
}

int main(void) {
    printf("=== Starting B3 Test Harness ===\n");
    signal(SIGALRM, timeout_handler);
    alarm(3);

    metrics_init(&g_mt);

    pthread_t tw, ta;
    pthread_create(&tw, NULL, worker_ab, NULL);
    pthread_create(&ta, NULL, auditor, NULL);

    pthread_join(tw, NULL);
    stop_harness(false);
    pthread_join(ta, NULL);

    int64_t final_a = 0, final_b = 0;
    metrics_read_snapshot(&g_mt, &final_a, &final_b);
    metrics_destroy(&g_mt);

    bool violation = check_violation();
    if (violation) {
        fprintf(stderr, ">>> FAULT DETECTED: Inconsistent balance check observed <<<\n");
        return 1;
    }

    if (final_a + final_b != B3_TOTAL_BALANCE) {
        fprintf(stderr, ">>> FAULT DETECTED: Final balance sum mismatch (%ld != %lld)! <<<\n",
                (long)(final_a + final_b), (long long)B3_TOTAL_BALANCE);
        return 1;
    }

    printf(">>> SUCCESS: Invariant preserved across all threads <<<\n");
    alarm(0);
    return 0;
}
