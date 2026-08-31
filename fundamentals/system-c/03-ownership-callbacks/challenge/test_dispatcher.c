#include "dispatcher.h"
#include <errno.h>
#include <stdio.h>

struct count_ctx { int calls; int sum; int fail_on; };
static int count_cb(const struct record *r, void *ctx)
{
    struct count_ctx *c = ctx;
    ++c->calls;
    c->sum += r->value;
    return c->fail_on == c->calls ? EIO : 0;
}

int main(void)
{
    struct dispatcher d;
    struct count_ctx a = {0,0,0}, b = {0,0,1};
    struct record r = {7};
    dispatcher_init(&d);
    if (dispatcher_add(&d, count_cb, &a) != 0) return 1;
    if (dispatcher_add(&d, count_cb, &b) != 0) return 1;
    if (dispatcher_emit(&d, &r) != EIO) return 1;
    printf("a_calls=%d b_calls=%d a_sum=%d\n", a.calls, b.calls, a.sum);
    return a.calls == 1 && b.calls == 1 ? 0 : 1;
}
