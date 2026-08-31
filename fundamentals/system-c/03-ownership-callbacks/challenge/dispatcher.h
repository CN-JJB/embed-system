#ifndef DISPATCHER_H
#define DISPATCHER_H
#include <stddef.h>

struct record { int value; };
typedef int (*record_fn)(const struct record *, void *ctx);
#define DISPATCHER_CAPACITY 4U
struct callback_slot { record_fn fn; void *ctx; };
struct dispatcher { struct callback_slot slots[DISPATCHER_CAPACITY]; size_t count; int dispatching; };

void dispatcher_init(struct dispatcher *d);
int dispatcher_add(struct dispatcher *d, record_fn fn, void *ctx);
int dispatcher_emit(struct dispatcher *d, const struct record *record);
#endif
