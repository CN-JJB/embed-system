#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct frame { size_t len; unsigned char *data; };
struct record { int value; };
struct callback_slot { int (*fn)(const struct record *, void *); void *ctx; };
struct safe_ctx { int total; int last_value; int saw; };
static int fail_construction;

static int frame_create(size_t len, struct frame **out)
{
    struct frame *f;
    if (out == NULL || *out != NULL || len == 0) return EINVAL;
    f = malloc(sizeof *f);
    if (f == NULL) return ENOMEM;
    f->data = NULL;
    if (fail_construction) { free(f); return ENOMEM; }
    f->data = calloc(len, 1U);
    if (f->data == NULL) { free(f); return ENOMEM; }
    f->len = len;
    *out = f;
    return 0;
}
static void frame_destroy(struct frame **p)
{
    if (p == NULL || *p == NULL) return;
    free((*p)->data); free(*p); *p = NULL;
}
static int observe_cb(const struct record *r, void *ctx)
{
    struct safe_ctx *c = ctx;
    if (r == NULL || c == NULL) return EINVAL;
    c->total += r->value;
    c->last_value = r->value;
    c->saw = 1;
    return 0;
}
static int borrowed_use(const struct record *r) { return r == NULL ? EINVAL : r->value; }

int main(int argc, char **argv)
{
    if (argc != 2) return 64;
    if (strcmp(argv[1], "owned") == 0) {
        struct record *owner = malloc(sizeof *owner);
        int v;
        if (owner == NULL) return 2;
        owner->value = 4;
        v = borrowed_use(owner);
        free(owner);
        printf("borrowed_value=%d\n", v);
        return v == 4 ? 0 : 1;
    }
    if (strcmp(argv[1], "output") == 0) {
        struct frame *f = NULL;
        int rc;
        fail_construction = 1;
        rc = frame_create(8U, &f);
        printf("failure_rc=%d output_null=%s\n", rc, f == NULL ? "yes" : "no");
        fail_construction = 0;
        if (frame_create(8U, &f) != 0) return 1;
        frame_destroy(&f); frame_destroy(&f);
        return rc == ENOMEM && f == NULL ? 0 : 1;
    }
    if (strcmp(argv[1], "ctx") == 0 || strcmp(argv[1], "retain") == 0) {
        struct safe_ctx ctx = {0,0,0};
        struct callback_slot slot = {observe_cb, &ctx};
        struct record r = {9};
        int rc = slot.fn(&r, slot.ctx);
        printf("total=%d last=%d retained_pointer=no\n", ctx.total, ctx.last_value);
        return rc == 0 && ctx.saw && ctx.total == 9 ? 0 : 1;
    }
    return 64;
}
