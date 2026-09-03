#ifndef PART_D_REF_PIPELINE_H
#define PART_D_REF_PIPELINE_H

#include "queue.h"
#include <pthread.h>
#include <stdint.h>
#include <stdbool.h>

struct telemetry_pipeline {
    int input_fd;
    struct bounded_queue queue;
    pthread_t consumer_thread;
    pthread_t reader_thread;
    bool consumer_created;
    bool reader_created;

    pthread_mutex_t stats_lock;
    uint64_t processed_count;
    int64_t accumulated_sum;

    pthread_mutex_t sync_lock;
    pthread_cond_t sync_cond;
    bool shutdown_signaled;
    bool consumer_completed;
    bool active;
};

int pipeline_start(struct telemetry_pipeline *pl, int in_fd);
int pipeline_stop(struct telemetry_pipeline *pl);
void pipeline_destroy(struct telemetry_pipeline *pl);
void pipeline_get_stats(struct telemetry_pipeline *pl, uint64_t *out_count, int64_t *out_sum);
bool pipeline_is_completed(struct telemetry_pipeline *pl);

#endif /* PART_D_REF_PIPELINE_H */
