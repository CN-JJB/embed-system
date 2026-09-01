#ifndef SHARED_STATS_H
#define SHARED_STATS_H
#include <pthread.h>
#include <stdint.h>
struct stats_snapshot{uint64_t count;int64_t sum;int32_t min,max;int initialized;};struct shared_stats{uint64_t count;int64_t sum;int32_t min,max;int initialized;pthread_mutex_t mutex;};int stats_init(struct shared_stats*s);int stats_add(struct shared_stats*s,int32_t value);int stats_snapshot(struct shared_stats*s,struct stats_snapshot*out);int stats_destroy(struct shared_stats*s);
#endif
