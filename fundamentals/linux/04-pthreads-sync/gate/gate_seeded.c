#define _DEFAULT_SOURCE
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>
#include <assert.h>

/*
 * M09 GATE SEEDED FAULT HARNESS
 *
 * Exercises three concurrency fault domains:
 * 1. "race"      — unsynchronized shared access (lost updates & data race).
 * 2. "invariant" — multi-field invariant violation (unprotected multi-field state).
 * 3. "condvar"   — condition variable predicate/close bug (missing wake on close).
 *
 * Usage: ./gate_seeded [race|invariant|condvar|all]
 */

/* =========================================================================
 * FAULT 1: RACE (Unsynchronized Shared Counter)
 * ========================================================================= */
#define RACE_ITERS 150000
static long g_race_counter = 0;

static void *race_worker(void *arg) {
    (void)arg;
    for (long i = 0; i < RACE_ITERS; i++) {
        /* SEEDED BUG: Unsynchronized read-modify-write */
        g_race_counter++;
    }
    return NULL;
}

static int run_fault_race(void) {
    printf("--- Running Seeded Fault 1: Race (Unsynchronized Shared Access) ---\n");
    g_race_counter = 0;
    pthread_t t1, t2;
    pthread_create(&t1, NULL, race_worker, NULL);
    pthread_create(&t2, NULL, race_worker, NULL);
    pthread_join(t1, NULL);
    pthread_join(t2, NULL);

    long expected = RACE_ITERS * 2;
    printf("Result: counter=%ld (expected=%ld)\n", g_race_counter, expected);
    if (g_race_counter != expected) {
        printf(">>> FAULT REPRODUCED: Lost update race detected (difference=%ld) <<<\n",
               expected - g_race_counter);
        return 1;
    } else {
        printf("Race did not manifest in this schedule. Run with TSan or repeat.\n");
        return 0;
    }
}

/* =========================================================================
 * FAULT 2: INVARIANT (Multi-field Invariant Violation)
 * Invariant: account_a + account_b == TOTAL_FUNDS (10000) at all observation points.
 * ========================================================================= */
#define TOTAL_FUNDS 10000
#define TRANSFER_ITERS 100000

static struct {
    int account_a;
    int account_b;
    pthread_mutex_t lock;
    int stop;
} g_bank;

static void *transfer_worker(void *arg) {
    (void)arg;
    for (int i = 0; i < TRANSFER_ITERS && !g_bank.stop; i++) {
        /* SEEDED BUG: Lock is released between debit and credit, exposing broken invariant */
        pthread_mutex_lock(&g_bank.lock);
        g_bank.account_a -= 50;
        pthread_mutex_unlock(&g_bank.lock);

        /* Window of vulnerability: invariant is violated here! */
        usleep(1);

        pthread_mutex_lock(&g_bank.lock);
        g_bank.account_b += 50;
        pthread_mutex_unlock(&g_bank.lock);

        /* Reverse transfer */
        pthread_mutex_lock(&g_bank.lock);
        g_bank.account_b -= 50;
        pthread_mutex_unlock(&g_bank.lock);

        usleep(1);

        pthread_mutex_lock(&g_bank.lock);
        g_bank.account_a += 50;
        pthread_mutex_unlock(&g_bank.lock);
    }
    return NULL;
}

static void *auditor_worker(void *arg) {
    int *violations = (int *)arg;
    for (int i = 0; i < 2000; i++) {
        /* Auditor reads without lock or during vulnerability window */
        pthread_mutex_lock(&g_bank.lock);
        int a = g_bank.account_a;
        int b = g_bank.account_b;
        pthread_mutex_unlock(&g_bank.lock);

        int sum = a + b;
        if (sum != TOTAL_FUNDS) {
            printf(">>> FAULT REPRODUCED: Invariant violation! a=%d b=%d sum=%d (expected %d) <<<\n",
                   a, b, sum, TOTAL_FUNDS);
            (*violations)++;
            g_bank.stop = 1;
            break;
        }
        usleep(50);
    }
    return NULL;
}

static int run_fault_invariant(void) {
    printf("--- Running Seeded Fault 2: Multi-Field Invariant Violation ---\n");
    g_bank.account_a = 5000;
    g_bank.account_b = 5000;
    g_bank.stop = 0;
    pthread_mutex_init(&g_bank.lock, NULL);

    int violations = 0;
    pthread_t t_transfer, t_auditor;
    pthread_create(&t_transfer, NULL, transfer_worker, NULL);
    pthread_create(&t_auditor, NULL, auditor_worker, &violations);

    pthread_join(t_auditor, NULL);
    g_bank.stop = 1;
    pthread_join(t_transfer, NULL);
    pthread_mutex_destroy(&g_bank.lock);

    return violations > 0 ? 1 : 0;
}

/* =========================================================================
 * FAULT 3: CONDVAR (Condition Variable Close/Predicate Bug)
 * Worker waits on empty queue. Producer closes queue without condvar broadcast.
 * Bounded watchdog timer ensures harness terminates with diagnosis.
 * ========================================================================= */
static struct {
    int buffer[8];
    int count;
    int closed;
    pthread_mutex_t mutex;
    pthread_cond_t not_empty;
} g_gate_queue;

static void watchdog_handler(int sig) {
    (void)sig;
    const char msg[] = ">>> FAULT REPRODUCED: Watchdog timeout! Consumer hung waiting on condvar after close. <<<\n"
                       "Root cause: queue close changed predicate (closed=1) but failed to broadcast condition variable.\n";
    write(STDOUT_FILENO, msg, sizeof(msg) - 1);
    _exit(2);
}

static void *condvar_consumer(void *arg) {
    int *consumed_sum = (int *)arg;
    pthread_mutex_lock(&g_gate_queue.mutex);
    while (g_gate_queue.count == 0 && !g_gate_queue.closed) {
        pthread_cond_wait(&g_gate_queue.not_empty, &g_gate_queue.mutex);
    }
    while (g_gate_queue.count > 0) {
        *consumed_sum += g_gate_queue.buffer[--g_gate_queue.count];
    }
    pthread_mutex_unlock(&g_gate_queue.mutex);
    return NULL;
}

static int run_fault_condvar(void) {
    printf("--- Running Seeded Fault 3: Condvar Missing-Wake on Close ---\n");
    fflush(stdout);
    g_gate_queue.count = 0;
    g_gate_queue.closed = 0;
    pthread_mutex_init(&g_gate_queue.mutex, NULL);
    pthread_cond_init(&g_gate_queue.not_empty, NULL);

    /* Arm 2-second watchdog to catch the hang */
    signal(SIGALRM, watchdog_handler);
    alarm(2);

    int consumed = 0;
    pthread_t c;
    pthread_create(&c, NULL, condvar_consumer, &consumed);

    /* Allow consumer to enter wait state */
    usleep(50000);

    /* SEEDED BUG: Mark closed under lock, but DO NOT broadcast not_empty! */
    pthread_mutex_lock(&g_gate_queue.mutex);
    g_gate_queue.closed = 1;
    /* OMITTED: pthread_cond_broadcast(&g_gate_queue.not_empty); */
    pthread_mutex_unlock(&g_gate_queue.mutex);

    printf("Main thread closed queue without broadcast; waiting for consumer to join...\n");
    fflush(stdout);
    pthread_join(c, NULL);

    /* If it somehow joins without wake, disarm alarm */
    alarm(0);
    pthread_mutex_destroy(&g_gate_queue.mutex);
    pthread_cond_destroy(&g_gate_queue.not_empty);
    return 0;
}

int main(int argc, char **argv) {
    const char *mode = (argc > 1) ? argv[1] : "all";

    if (strcmp(mode, "race") == 0) {
        return run_fault_race();
    } else if (strcmp(mode, "invariant") == 0) {
        return run_fault_invariant();
    } else if (strcmp(mode, "condvar") == 0) {
        return run_fault_condvar();
    } else if (strcmp(mode, "all") == 0) {
        int r1 = run_fault_race();
        int r2 = run_fault_invariant();
        printf("(Running condvar station in subprocess to catch expected hang)\n");
        pid_t pid = fork();
        if (pid == 0) {
            run_fault_condvar();
            _exit(0);
        } else {
            int status = 0;
            waitpid(pid, &status, 0);
            printf("Condvar station exited with code %d (expected 2 from watchdog).\n",
                   WEXITSTATUS(status));
        }
        return (r1 || r2) ? 0 : 1;
    } else {
        fprintf(stderr, "Unknown mode '%s'. Use race, invariant, condvar, or all.\n", mode);
        return 1;
    }
}
