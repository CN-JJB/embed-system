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
    if (out == NULL || capacity == 0) {
        return EINVAL;
    }

    struct event_bus *bus = calloc(1, sizeof *bus);
    if (bus == NULL) {
        return ENOMEM;
    }

    bus->slots = calloc(capacity, sizeof bus->slots[0]);
    if (bus->slots == NULL) {
        free(bus);
        return ENOMEM;
    }

    bus->capacity = capacity;
    bus->next_token = 1;
    *out = bus;
    return 0;
}

void event_bus_destroy(struct event_bus **bus)
{
    if (bus == NULL || *bus == NULL) {
        return;
    }

    free((*bus)->slots);
    free(*bus);
    *bus = NULL;
}

int event_bus_register(struct event_bus *bus,
                       event_handler_t handler,
                       void *ctx,
                       unsigned *out_token)
{
    if (bus == NULL || handler == NULL || out_token == NULL) {
        return EINVAL;
    }

    for (size_t i = 0; i < bus->capacity; ++i) {
        if (bus->slots[i].handler == NULL) {
            unsigned token = bus->next_token++;
            if (token == 0) {
                token = bus->next_token++;
            }

            bus->slots[i].handler = handler;
            bus->slots[i].ctx = ctx;
            bus->slots[i].token = token;
            *out_token = token;
            return 0;
        }
    }

    return ENOSPC;
}

int event_bus_unregister(struct event_bus *bus, unsigned token)
{
    if (bus == NULL || token == 0) {
        return EINVAL;
    }

    for (size_t i = 0; i < bus->capacity; ++i) {
        if (bus->slots[i].handler != NULL && bus->slots[i].token == token) {
            bus->slots[i].handler = NULL;
            bus->slots[i].ctx = NULL;
            bus->slots[i].token = 0;
            return 0;
        }
    }

    return ENOENT;
}

int event_bus_emit(struct event_bus *bus,
                   int event,
                   const void *data,
                   size_t size)
{
    if (bus == NULL || (data == NULL && size != 0)) {
        return EINVAL;
    }

    for (size_t i = 0; i < bus->capacity; ++i) {
        if (bus->slots[i].handler != NULL) {
            bus->slots[i].handler(event, data, size, bus->slots[i].ctx);
        }
    }

    return 0;
}
