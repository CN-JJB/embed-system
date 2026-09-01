#include "queue.h"
#include <string.h>
int record_queue_init(struct record_queue *q) {
    int rc;
    if (!q) return QUEUE_ERROR;
    memset(q,0,sizeof(*q));
    rc=pthread_mutex_init(&q->mutex,0); if(rc) return QUEUE_ERROR;
    rc=pthread_cond_init(&q->not_empty,0); if(rc){pthread_mutex_destroy(&q->mutex);return QUEUE_ERROR;}
    rc=pthread_cond_init(&q->not_full,0); if(rc){pthread_cond_destroy(&q->not_empty);pthread_mutex_destroy(&q->mutex);return QUEUE_ERROR;}
    return QUEUE_OK;
}
int record_queue_push(struct record_queue *q,const struct telemetry_record *r) {
    int rc;if(!q||!r)return QUEUE_ERROR; if(pthread_mutex_lock(&q->mutex))return QUEUE_ERROR;
    while(q->count==QUEUE_CAPACITY && !q->closed){rc=pthread_cond_wait(&q->not_full,&q->mutex);if(rc){pthread_mutex_unlock(&q->mutex);return QUEUE_ERROR;}}
    if(q->closed){pthread_mutex_unlock(&q->mutex);return QUEUE_CLOSED;}
    q->items[q->tail]=*r;q->tail=(q->tail+1u)%QUEUE_CAPACITY;q->count++;
    rc=pthread_cond_signal(&q->not_empty); if(pthread_mutex_unlock(&q->mutex)||rc)return QUEUE_ERROR; return QUEUE_OK;
}
int record_queue_pop(struct record_queue *q,struct telemetry_record *out) {
    int rc;if(!q||!out)return QUEUE_ERROR; if(pthread_mutex_lock(&q->mutex))return QUEUE_ERROR;
    while(q->count==0 && !q->closed){rc=pthread_cond_wait(&q->not_empty,&q->mutex);if(rc){pthread_mutex_unlock(&q->mutex);return QUEUE_ERROR;}}
    if(q->count==0 && q->closed){pthread_mutex_unlock(&q->mutex);return QUEUE_CLOSED;}
    *out=q->items[q->head];q->head=(q->head+1u)%QUEUE_CAPACITY;q->count--;
    rc=pthread_cond_signal(&q->not_full); if(pthread_mutex_unlock(&q->mutex)||rc)return QUEUE_ERROR; return QUEUE_OK;
}
int record_queue_close(struct record_queue *q){int a,b;if(!q)return QUEUE_ERROR;if(pthread_mutex_lock(&q->mutex))return QUEUE_ERROR;q->closed=1;a=pthread_cond_broadcast(&q->not_empty);b=pthread_cond_broadcast(&q->not_full);if(pthread_mutex_unlock(&q->mutex)||a||b)return QUEUE_ERROR;return QUEUE_OK;}
int record_queue_destroy(struct record_queue *q){int a,b,c;if(!q)return QUEUE_ERROR;a=pthread_cond_destroy(&q->not_empty);b=pthread_cond_destroy(&q->not_full);c=pthread_mutex_destroy(&q->mutex);return (a||b||c)?QUEUE_ERROR:QUEUE_OK;}
