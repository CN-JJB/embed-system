#include "event_bus.h"

#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

struct observer {
    int calls;
    int last_event;
    char last_payload[16];
};

static void observe(int event, const void *data, size_t size, void *ctx)
{
    struct observer *o = ctx;
    ++o->calls;
    o->last_event = event;
    size_t n = size < sizeof o->last_payload - 1 ? size : sizeof o->last_payload - 1;
    memcpy(o->last_payload, data, n);
    o->last_payload[n] = '\0';
}

int main(void)
{
    struct event_bus *bus = NULL;
    struct observer a = {0};
    struct observer b = {0};
    unsigned ta = 0, tb = 0, extra = 0;

    assert(event_bus_create(NULL, 2) == EINVAL);
    assert(event_bus_create(&bus, 0) == EINVAL);
    assert(event_bus_create(&bus, 2) == 0);
    assert(bus != NULL);

    assert(event_bus_register(bus, observe, &a, &ta) == 0);
    assert(event_bus_register(bus, observe, &b, &tb) == 0);
    assert(ta != 0 && tb != 0 && ta != tb);
    assert(event_bus_register(bus, observe, &a, &extra) == ENOSPC);

    assert(event_bus_emit(bus, 42, "ok", 2) == 0);
    assert(a.calls == 1 && b.calls == 1);
    assert(a.last_event == 42 && strcmp(a.last_payload, "ok") == 0);

    assert(event_bus_unregister(bus, ta) == 0);
    assert(event_bus_unregister(bus, ta) == ENOENT);
    assert(event_bus_emit(bus, 7, "x", 1) == 0);
    assert(a.calls == 1 && b.calls == 2);

    event_bus_destroy(&bus);
    assert(bus == NULL);
    event_bus_destroy(&bus);

    puts("event_bus tests: PASS");
    return 0;
}
