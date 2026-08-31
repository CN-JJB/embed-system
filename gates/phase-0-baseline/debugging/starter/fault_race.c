#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static volatile uint64_t counter;

enum { THREADS = 4, ITERATIONS = 250000 };

static void *worker(void *arg)
{
    (void)arg;
    for (int i = 0; i < ITERATIONS; ++i) {
        ++counter;
    }
    return NULL;
}

int main(void)
{
    pthread_t threads[THREADS];

    for (int i = 0; i < THREADS; ++i) {
        if (pthread_create(&threads[i], NULL, worker, NULL) != 0) {
            perror("pthread_create");
            return 1;
        }
    }
    for (int i = 0; i < THREADS; ++i) {
        pthread_join(threads[i], NULL);
    }

    uint64_t expected = (uint64_t)THREADS * ITERATIONS;
    printf("counter=%llu expected=%llu\n",
           (unsigned long long)counter,
           (unsigned long long)expected);
    return counter == expected ? 0 : 1;
}
