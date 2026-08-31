#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static double seconds_since(const struct timespec *a, const struct timespec *b)
{
    return (double)(b->tv_sec - a->tv_sec) +
           (double)(b->tv_nsec - a->tv_nsec) / 1000000000.0;
}

static double run_pattern(const uint32_t *a, size_t n, size_t stride, size_t accesses,
                          volatile uint64_t *sink)
{
    size_t idx = 0;
    uint64_t sum = 0;
    struct timespec t0, t1;

    clock_gettime(CLOCK_MONOTONIC, &t0);
    for (size_t i = 0; i < accesses; ++i) {
        sum += a[idx];
        idx += stride;
        if (idx >= n) {
            idx -= n;
        }
    }
    clock_gettime(CLOCK_MONOTONIC, &t1);

    *sink = sum;
    return seconds_since(&t0, &t1);
}

int main(void)
{
    const size_t n = 8u * 1024u * 1024u; /* 32 MiB of uint32_t */
    const size_t accesses = n * 2u;
    const size_t stride = 1021u;          /* 4084 bytes, odd => visits whole power-of-two array */
    uint32_t *a = malloc(n * sizeof *a);
    volatile uint64_t sink = 0;

    if (a == NULL) {
        perror("malloc");
        return 1;
    }
    for (size_t i = 0; i < n; ++i) {
        a[i] = (uint32_t)(i * 2654435761u);
    }

    double sequential = run_pattern(a, n, 1, accesses, &sink);
    double strided = run_pattern(a, n, stride, accesses, &sink);

    printf("sequential %.6f s\n", sequential);
    printf("strided    %.6f s\n", strided);
    printf("sink=%llu\n", (unsigned long long)sink);

    free(a);
    return 0;
}
