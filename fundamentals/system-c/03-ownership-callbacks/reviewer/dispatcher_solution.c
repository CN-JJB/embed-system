#include "../challenge/dispatcher.h"
#include <errno.h>

void dispatcher_init(struct dispatcher *d)
{
    if (d != NULL) { d->count = 0U; d->dispatching = 0; }
}
int dispatcher_add(struct dispatcher *d, record_fn fn, void *ctx)
{
    if (d == NULL || fn == NULL) return EINVAL;
    if (d->dispatching) return EBUSY;
    if (d->count >= DISPATCHER_CAPACITY) return ENOSPC;
    d->slots[d->count].fn = fn;
    d->slots[d->count].ctx = ctx;
    ++d->count;
    return 0;
}
int dispatcher_emit(struct dispatcher *d, const struct record *record)
{
    size_t i;
    int rc = 0;
    if (d == NULL || record == NULL) return EINVAL;
    if (d->dispatching) return EBUSY;
    d->dispatching = 1;
    for (i = 0; i < d->count; ++i) {
        rc = d->slots[i].fn(record, d->slots[i].ctx);
        if (rc != 0) break;
    }
    d->dispatching = 0;
    return rc;
}
