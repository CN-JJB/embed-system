#ifndef PART_D_QUEUE_H
#define PART_D_QUEUE_H

#include <stdint.h>
#include <stddef.h>
#include <pthread.h>
#include <stdbool.h>

#define QUEUE_CAPACITY 32

struct queue_item {
    uint64_t id;
    int32_t value;
};

struct bounded_queue {
    pthread_mutex_t lock;
    pthread_cond_t not_empty;
    pthread_cond_t not_full;
    struct queue_item items[QUEUE_CAPACITY];
    size_t head;
    size_t tail;
    size_t count;
    bool closed;
};

int queue_init(struct bounded_queue *q);
int queue_push(struct bounded_queue *q, const struct queue_item *item);
int queue_pop(struct bounded_queue *q, struct queue_item *out_item);
void queue_close(struct bounded_queue *q);
void queue_destroy(struct bounded_queue *q);

#endif /* PART_D_QUEUE_H */
