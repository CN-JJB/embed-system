#include "dispatcher.h"
#include <errno.h>

void dispatcher_init(struct dispatcher *d)
{
    if (d != NULL) { d->count = 0U; d->dispatching = 0; }
}
int dispatcher_add(struct dispatcher *d, record_fn fn, void *ctx)
{
    (void)d; (void)fn; (void)ctx;
    return ENOSYS;
}
int dispatcher_emit(struct dispatcher *d, const struct record *record)
{
    (void)d; (void)record;
    return ENOSYS;
}
