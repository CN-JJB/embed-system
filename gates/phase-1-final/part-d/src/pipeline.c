#define _POSIX_C_SOURCE 200809L
#include "pipeline.h"
#include <unistd.h>
#include <stdio.h>
#include <errno.h>

static void *reader_worker(void *arg) {
    struct telemetry_pipeline *pl = (struct telemetry_pipeline *)arg;
    struct queue_item item;

    for (;;) {
        ssize_t n = read(pl->input_fd, &item, sizeof(item));
        if (n <= 0) {
            if (n < 0 && errno == EINTR) {
                continue;
            }
            /* EOF or unrecoverable error */
            break;
        }
        if (n == sizeof(item)) {
            if (queue_push(&pl->queue, &item) != 0) {
                break;
            }
        }
    }

    queue_close(&pl->queue);
    return NULL;
}

static void *consumer_worker(void *arg) {
    struct telemetry_pipeline *pl = (struct telemetry_pipeline *)arg;
    struct queue_item item;

    for (;;) {
        int res = queue_pop(&pl->queue, &item);
        if (res == -1) {
            break; /* Queue closed and drained */
        }
        if (res == 0) {
            pl->processed_count++;
            pl->accumulated_sum += item.value;
        }
    }

    return NULL;
}

int pipeline_start(struct telemetry_pipeline *pl, int in_fd) {
    pl->input_fd = in_fd;
    pl->processed_count = 0;
    pl->accumulated_sum = 0;
    pl->active = true;

    if (queue_init(&pl->queue) != 0) {
        return -1;
    }

    if (pthread_create(&pl->reader_thread, NULL, reader_worker, pl) != 0) {
        queue_destroy(&pl->queue);
        return -1;
    }

    if (pthread_create(&pl->consumer_thread, NULL, consumer_worker, pl) != 0) {
        queue_close(&pl->queue);
        pthread_join(pl->reader_thread, NULL);
        queue_destroy(&pl->queue);
        return -1;
    }

    return 0;
}

int pipeline_stop(struct telemetry_pipeline *pl) {
    if (!pl->active) {
        return 0;
    }

    /*
     * BUGGY CONCURRENCY LIFECYCLE ORDERING:
     * Destroys queue synchronization primitives BEFORE joining worker threads!
     * The worker thread may still be running or exiting, causing EBUSY or accessing destroyed mutex.
     */
    queue_destroy(&pl->queue);

    pthread_join(pl->reader_thread, NULL);
    pthread_join(pl->consumer_thread, NULL);

    pl->active = false;
    return 0;
}
