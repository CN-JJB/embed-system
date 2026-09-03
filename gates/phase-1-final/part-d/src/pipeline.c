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
            break;
        }
        pthread_mutex_lock(&pl->stats_lock);
        pl->processed_count++;
        pl->accumulated_sum += item.value;
        pthread_mutex_unlock(&pl->stats_lock);
    }

    pthread_mutex_lock(&pl->sync_lock);
    while (!pl->shutdown_signaled) {
        pthread_cond_wait(&pl->sync_cond, &pl->sync_lock);
    }
    pl->consumer_completed = true;
    pthread_mutex_unlock(&pl->sync_lock);

    return NULL;
}

int pipeline_start(struct telemetry_pipeline *pl, int in_fd) {
    pl->input_fd = in_fd;
    pl->processed_count = 0;
    pl->accumulated_sum = 0;
    pl->consumer_created = false;
    pl->reader_created = false;
    pl->shutdown_signaled = false;
    pl->consumer_completed = false;
    pl->active = true;

    if (queue_init(&pl->queue) != 0) {
        return -1;
    }
    if (pthread_mutex_init(&pl->stats_lock, NULL) != 0) {
        queue_destroy(&pl->queue);
        return -1;
    }
    if (pthread_mutex_init(&pl->sync_lock, NULL) != 0) {
        pthread_mutex_destroy(&pl->stats_lock);
        queue_destroy(&pl->queue);
        return -1;
    }
    if (pthread_cond_init(&pl->sync_cond, NULL) != 0) {
        pthread_mutex_destroy(&pl->sync_lock);
        pthread_mutex_destroy(&pl->stats_lock);
        queue_destroy(&pl->queue);
        return -1;
    }

    if (pthread_create(&pl->consumer_thread, NULL, consumer_worker, pl) != 0) {
        pthread_cond_destroy(&pl->sync_cond);
        pthread_mutex_destroy(&pl->sync_lock);
        pthread_mutex_destroy(&pl->stats_lock);
        queue_destroy(&pl->queue);
        return -1;
    }
    pl->consumer_created = true;

    if (pthread_create(&pl->reader_thread, NULL, reader_worker, pl) != 0) {
        queue_close(&pl->queue);
        pthread_mutex_lock(&pl->sync_lock);
        pl->shutdown_signaled = true;
        pthread_cond_broadcast(&pl->sync_cond);
        pthread_mutex_unlock(&pl->sync_lock);
        pthread_join(pl->consumer_thread, NULL);
        pthread_cond_destroy(&pl->sync_cond);
        pthread_mutex_destroy(&pl->sync_lock);
        pthread_mutex_destroy(&pl->stats_lock);
        queue_destroy(&pl->queue);
        return -1;
    }
    pl->reader_created = true;

    return 0;
}

int pipeline_stop(struct telemetry_pipeline *pl) {
    if (!pl->active) {
        return 0;
    }

    if (pl->reader_created) {
        pthread_join(pl->reader_thread, NULL);
        pl->reader_created = false;
    }

    pl->active = false;
    return 0;
}

void pipeline_get_stats(struct telemetry_pipeline *pl, uint64_t *out_count, int64_t *out_sum) {
    pthread_mutex_lock(&pl->stats_lock);
    if (out_count) *out_count = pl->processed_count;
    if (out_sum) *out_sum = pl->accumulated_sum;
    pthread_mutex_unlock(&pl->stats_lock);
}

bool pipeline_is_completed(struct telemetry_pipeline *pl) {
    pthread_mutex_lock(&pl->sync_lock);
    bool c = pl->consumer_completed;
    pthread_mutex_unlock(&pl->sync_lock);
    return c;
}

void pipeline_destroy(struct telemetry_pipeline *pl) {
    pthread_mutex_lock(&pl->sync_lock);
    pl->shutdown_signaled = true;
    pthread_cond_broadcast(&pl->sync_cond);
    pthread_mutex_unlock(&pl->sync_lock);

    if (pl->consumer_created) {
        pthread_join(pl->consumer_thread, NULL);
        pl->consumer_created = false;
    }
    if (pl->reader_created) {
        pthread_join(pl->reader_thread, NULL);
        pl->reader_created = false;
    }

    queue_destroy(&pl->queue);
    pthread_cond_destroy(&pl->sync_cond);
    pthread_mutex_destroy(&pl->sync_lock);
    pthread_mutex_destroy(&pl->stats_lock);
}
