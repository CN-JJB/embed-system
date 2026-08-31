#include <errno.h>
#include <stdio.h>

struct record { const char *name; int value; };
typedef int (*record_sink_fn)(const struct record *, void *ctx);
struct stats_ctx { unsigned count; long sum; };
struct text_ctx { FILE *stream; const char *prefix; };

static int stats_sink(const struct record *r, void *ctx)
{
    struct stats_ctx *s = ctx;
    if (r == NULL || s == NULL) return EINVAL;
    ++s->count; s->sum += r->value; return 0;
}
static int text_sink(const struct record *r, void *ctx)
{
    struct text_ctx *t = ctx;
    if (r == NULL || t == NULL || t->stream == NULL) return EINVAL;
    return fprintf(t->stream, "%s%s=%d\n", t->prefix, r->name, r->value) < 0 ? EIO : 0;
}
static int emit(const struct record *records, size_t n, record_sink_fn fn, void *ctx)
{
    size_t i;
    if (records == NULL || fn == NULL) return EINVAL;
    for (i = 0; i < n; ++i) {
        int rc = fn(&records[i], ctx);
        if (rc != 0) return rc;
    }
    return 0;
}

int main(void)
{
    const struct record records[] = {{"a", 2}, {"b", 3}, {"c", 5}};
    struct stats_ctx stats = {0U, 0};
    struct text_ctx text = {stdout, "obs:"};
    if (emit(records, 3U, stats_sink, &stats) != 0) return 1;
    if (emit(records, 3U, text_sink, &text) != 0) return 1;
    printf("count=%u sum=%ld\n", stats.count, stats.sum);
    return stats.count == 3U && stats.sum == 10 ? 0 : 1;
}
