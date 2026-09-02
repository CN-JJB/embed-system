#ifndef QUEUE_H
#define QUEUE_H
#include <pthread.h>
#include <stddef.h>
#include "telemetry.h"
#define QUEUE_CAPACITY 8u
enum queue_status { QUEUE_OK=0, QUEUE_CLOSED=1, QUEUE_ERROR=2 };
struct record_queue { struct telemetry_record items[QUEUE_CAPACITY]; size_t head,tail,count; int closed; pthread_mutex_t mutex; pthread_cond_t not_empty,not_full; };
int record_queue_init(struct record_queue *q);
int record_queue_push(struct record_queue *q,const struct telemetry_record *r);
int record_queue_pop(struct record_queue *q,struct telemetry_record *out);
int record_queue_close(struct record_queue *q);
int record_queue_destroy(struct record_queue *q);
#endif
