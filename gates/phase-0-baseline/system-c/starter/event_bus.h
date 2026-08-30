#ifndef EVENT_BUS_H
#define EVENT_BUS_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*event_handler_t)(
    int event,
    const void *data,
    size_t size,
    void *ctx
);

struct event_bus;

int event_bus_create(struct event_bus **out, size_t capacity);
void event_bus_destroy(struct event_bus **bus);
int event_bus_register(struct event_bus *bus,
                       event_handler_t handler,
                       void *ctx,
                       unsigned *out_token);
int event_bus_unregister(struct event_bus *bus, unsigned token);
int event_bus_emit(struct event_bus *bus,
                   int event,
                   const void *data,
                   size_t size);

#ifdef __cplusplus
}
#endif

#endif
