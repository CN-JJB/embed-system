#include "event_bus.h"

#include <errno.h>
#include <stdlib.h>

struct event_slot {
    event_handler_t handler;
    void *ctx;
    unsigned token;
};

struct event_bus {
    struct event_slot *slots;
    size_t capacity;
    unsigned next_token;
};

int event_bus_create(struct event_bus **out, size_t capacity)
{
    (void)out;
    (void)capacity;
    return ENOSYS;
}

void event_bus_destroy(struct event_bus **bus)
{
    (void)bus;
}

int event_bus_register(struct event_bus *bus,
                       event_handler_t handler,
                       void *ctx,
                       unsigned *out_token)
{
    (void)bus;
    (void)handler;
    (void)ctx;
    (void)out_token;
    return ENOSYS;
}

int event_bus_unregister(struct event_bus *bus, unsigned token)
{
    (void)bus;
    (void)token;
    return ENOSYS;
}

int event_bus_emit(struct event_bus *bus,
                   int event,
                   const void *data,
                   size_t size)
{
    (void)bus;
    (void)event;
    (void)data;
    (void)size;
    return ENOSYS;
}
