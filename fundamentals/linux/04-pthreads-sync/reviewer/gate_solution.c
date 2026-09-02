#define _DEFAULT_SOURCE
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <assert.h>

/*
 * M09 GATE REVIEWER REFERENCE SOLUTION
 *
 * Implements the verified repair for each domain:
 * 1. "race":      mutex protects shared counter read-modify-write.
 * 2. "invariant": atomic transfer under mutex holds account_a + account_b == 10000.
 * 3. "condvar":   predicate while loop + closed flag + broadcast wakes all sleepers.
 *
 * Usage: ./gate_solution [race|invariant|condvar|all]
 */

/* =========================================================================
 * DOMAIN 1: RACE REPAIR
 * Protected Invariant: g_counter represents exact number of completed increments.
 * ========================================================================= */
#define RACE_ITERS 150000
static long g_counter = 0;
static pthread_mutex_t g_counter_lock = PTHREAD_MUTEX_INITIALIZER;

static void *fixed_race_worker(void *arg) {
    (void)arg;
    for (long i = 0; i < RACE_ITERS; i++) {
        pthread_mutex_lock(&g_counter_lock);
        g_counter++;
        pthread_mutex_unlock(&g_counter_lock);
    }
    return NULL;
}

static int run_fixed_race(void) {
    printf("--- Running Fixed Domain 1: Protected Counter ---\n");
    g_counter = 0;
    pthread_t t1, t2;
    assert(pthread_create(&t1, NULL, fixed_race_worker, NULL) == 0);
    assert(pthread_create(&t2, NULL, fixed_race_worker, NULL) == 0);
    assert(pthread_join(t1, NULL) == 0);
    assert(pthread_join(t2, NULL) == 0);

    long expected = RACE_ITERS * 2;
    printf("Result: counter=%ld (expected=%ld)\n", g_counter, expected);
    assert(g_counter == expected);
    printf("Domain 1: PASSED\n");
    return 0;
}

/* =========================================================================
 * DOMAIN 2: INVARIANT REPAIR
 * Protected Invariant: account_a + account_b == TOTAL_FUNDS (10000).
 * State transition must hold lock across debit AND credit.
 * ========================================================================= */
#define TOTAL_FUNDS 10000
#define TRANSFER_ITERS 50000

static struct {
    int account_a;
    int account_b;
    pthread_mutex_t lock;
    int stop;
} g_fixed_bank;

static void *fixed_transfer_worker(void *arg) {
    (void)arg;
    for (int i = 0; i < TRANSFER_ITERS && !g_fixed_bank.stop; i++) {
        /* Entire balance adjustment is atomic under the mutex */
        pthread_mutex_lock(&g_fixed_bank.lock);
        g_fixed_bank.account_a -= 50;
        g_fixed_bank.account_b += 50;
        pthread_mutex_unlock(&g_fixed_bank.lock);

        /* Reverse transfer is also atomic */
        pthread_mutex_lock(&g_fixed_bank.lock);
        g_fixed_bank.account_b -= 50;
        g_fixed_bank.account_a += 50;
        pthread_mutex_unlock(&g_fixed_bank.lock);
    }
    return NULL;
}

static void *fixed_auditor_worker(void *arg) {
    int *violations = (int *)arg;
    for (int i = 0; i < 2000; i++) {
        pthread_mutex_lock(&g_fixed_bank.lock);
        int a = g_fixed_bank.account_a;
        int b = g_fixed_bank.account_b;
        pthread_mutex_unlock(&g_fixed_bank.lock);

        int sum = a + b;
        if (sum != TOTAL_FUNDS) {
            printf("FAIL: Invariant violation detected: sum=%d\n", sum);
            (*violations)++;
            break;
        }
        usleep(20);
    }
    return NULL;
}

static int run_fixed_invariant(void) {
    printf("--- Running Fixed Domain 2: Multi-Field Invariant ---\n");
    g_fixed_bank.account_a = 5000;
    g_fixed_bank.account_b = 5000;
    g_fixed_bank.stop = 0;
    assert(pthread_mutex_init(&g_fixed_bank.lock, NULL) == 0);

    int violations = 0;
    pthread_t t_transfer, t_auditor;
    assert(pthread_create(&t_transfer, NULL, fixed_transfer_worker, NULL) == 0);
    assert(pthread_create(&t_auditor, NULL, fixed_auditor_worker, &violations) == 0);

    assert(pthread_join(t_auditor, NULL) == 0);
    g_fixed_bank.stop = 1;
    assert(pthread_join(t_transfer, NULL) == 0);
    assert(pthread_mutex_destroy(&g_fixed_bank.lock) == 0);

    assert(violations == 0);
    printf("Domain 2: PASSED (0 invariant violations observed across audit cycles)\n");
    return 0;
}

/* =========================================================================
 * DOMAIN 3: CONDVAR PREDICATE & CLOSE REPAIR
 * Requirements:
 * - Consumer waits in while (!closed && count == 0) loop.
 * - Close sets closed = 1 and calls broadcast under mutex.
 * - Consumer drains items, sees closed && count == 0, exits cleanly.
 * - Thread joined before condvar/mutex destroyed.
 * ========================================================================= */
static struct {
    int buffer[8];
    int count;
    int closed;
    pthread_mutex_t mutex;
    pthread_cond_t not_empty;
} g_fixed_queue;

static void *fixed_condvar_consumer(void *arg) {
    int *consumed_sum = (int *)arg;
    pthread_mutex_lock(&g_fixed_queue.mutex);
    while (g_fixed_queue.count == 0 && !g_fixed_queue.closed) {
        pthread_cond_wait(&g_fixed_queue.not_empty, &g_fixed_queue.mutex);
    }
    while (g_fixed_queue.count > 0) {
        *consumed_sum += g_fixed_queue.buffer[--g_fixed_queue.count];
    }
    pthread_mutex_unlock(&g_fixed_queue.mutex);
    return NULL;
}

static int run_fixed_condvar(void) {
    printf("--- Running Fixed Domain 3: Condvar Predicate & Close ---\n");
    g_fixed_queue.count = 0;
    g_fixed_queue.closed = 0;
    assert(pthread_mutex_init(&g_fixed_queue.mutex, NULL) == 0);
    assert(pthread_cond_init(&g_fixed_queue.not_empty, NULL) == 0);

    int consumed = 0;
    pthread_t c;
    assert(pthread_create(&c, NULL, fixed_condvar_consumer, &consumed) == 0);

    /* Allow consumer to block on condvar */
    usleep(20000);

    /* Enqueue one item and close with broadcast */
    pthread_mutex_lock(&g_fixed_queue.mutex);
    g_fixed_queue.buffer[g_fixed_queue.count++] = 42;
    g_fixed_queue.closed = 1;
    pthread_cond_broadcast(&g_fixed_queue.not_empty);
    pthread_mutex_unlock(&g_fixed_queue.mutex);

    assert(pthread_join(c, NULL) == 0);
    assert(consumed == 42);

    assert(pthread_mutex_destroy(&g_fixed_queue.mutex) == 0);
    assert(pthread_cond_destroy(&g_fixed_queue.not_empty) == 0);

    printf("Domain 3: PASSED (consumer woken on close, drained item, joined cleanly)\n");
    return 0;
}

int main(int argc, char **argv) {
    const char *mode = (argc > 1) ? argv[1] : "all";

    if (strcmp(mode, "race") == 0) {
        return run_fixed_race();
    } else if (strcmp(mode, "invariant") == 0) {
        return run_fixed_invariant();
    } else if (strcmp(mode, "condvar") == 0) {
        return run_fixed_condvar();
    } else if (strcmp(mode, "all") == 0) {
        int r1 = run_fixed_race();
        int r2 = run_fixed_invariant();
        int r3 = run_fixed_condvar();
        if (r1 == 0 && r2 == 0 && r3 == 0) {
            printf("=== All M09 Gate Fixed Domains PASSED ===\n");
            return 0;
        }
        return 1;
    } else {
        fprintf(stderr, "Unknown mode '%s'. Use race, invariant, condvar, or all.\n", mode);
        return 1;
    }
}
