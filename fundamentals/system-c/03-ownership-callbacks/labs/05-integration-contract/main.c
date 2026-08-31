#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

struct input { size_t n; int *values; };
struct record { size_t index; int value; };
struct stats_ctx { size_t count; long sum; };
typedef int (*record_fn)(const struct record *, void *ctx);

static int input_create(size_t n, struct input **out)
{
    struct input *in;
    if (out == NULL || *out != NULL || n == 0) return EINVAL;
    in = malloc(sizeof *in);
    if (in == NULL) return ENOMEM;
    in->values = calloc(n, sizeof *in->values);
    if (in->values == NULL) { free(in); return ENOMEM; }
    in->n = n; *out = in; return 0;
}
static void input_destroy(struct input **p)
{
    if (p == NULL || *p == NULL) return;
    free((*p)->values); free(*p); *p = NULL;
}
static int stats_sink(const struct record *r, void *ctx)
{
    struct stats_ctx *s = ctx;
    if (r == NULL || s == NULL) return EINVAL;
    ++s->count; s->sum += r->value; return 0;
}
static int process(const struct input *in, record_fn fn, void *ctx)
{
    size_t i;
    if (in == NULL || fn == NULL) return EINVAL;
    for (i = 0; i < in->n; ++i) {
        struct record r = {i, in->values[i]};
        int rc = fn(&r, ctx);
        if (rc != 0) return rc;
    }
    return 0;
}
int main(void)
{
    struct input *owned = NULL;
    struct stats_ctx stats = {0U, 0};
    size_t i;
    if (input_create(4U, &owned) != 0) return 1;
    for (i = 0; i < owned->n; ++i) owned->values[i] = (int)(i + 1U);
    if (process(owned, stats_sink, &stats) != 0) { input_destroy(&owned); return 1; }
    printf("count=%zu sum=%ld\n", stats.count, stats.sum);
    input_destroy(&owned);
    return owned == NULL && stats.count == 4U && stats.sum == 10 ? 0 : 1;
}
