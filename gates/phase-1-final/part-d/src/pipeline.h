#ifndef PART_D_PIPELINE_H
#define PART_D_PIPELINE_H

#include "queue.h"
#include <pthread.h>

struct telemetry_pipeline {
    int input_fd;
    struct bounded_queue queue;
    pthread_t reader_thread;
    pthread_t consumer_thread;
    uint64_t processed_count;
    int64_t accumulated_sum;
    bool active;
};

int pipeline_start(struct telemetry_pipeline *pl, int in_fd);
int pipeline_stop(struct telemetry_pipeline *pl);

#endif /* PART_D_PIPELINE_H */
