#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct frame { size_t len; unsigned char *data; };
struct record { int value; };
struct callback_slot { int (*fn)(const struct record *, void *); void *ctx; };
struct retained_ctx { const struct record *last; int total; };
static int fail_after_publish;

static int frame_create(size_t len, struct frame **out)
{
    struct frame *f;
    if (out == NULL || *out != NULL) return EINVAL;
    f = malloc(sizeof *f);
    if (f == NULL) return ENOMEM;
    *out = f;
    f->data = malloc(len);
    if (f->data == NULL || fail_after_publish) {
        free(f->data);
        free(f);
        return ENOMEM;
    }
    f->len = len;
    return 0;
}

static void consume_borrowed_and_free(const struct record *r)
{
    free((void *)r);
}

static int retain_cb(const struct record *r, void *ctx)
{
    struct retained_ctx *c = ctx;
    c->last = r;
    c->total += r->value;
    return 0;
}

static void release_ctx(struct retained_ctx **p)
{
    if (p != NULL && *p != NULL) { free(*p); *p = NULL; }
}

static int run_dangling_ctx(void)
{
    struct callback_slot slot;
    struct retained_ctx *ctx = malloc(sizeof *ctx);
    struct record r = {3};
    if (ctx == NULL) return 2;
    ctx->last = NULL; ctx->total = 0;
    slot.fn = retain_cb; slot.ctx = ctx;
    release_ctx(&ctx);
    return slot.fn(&r, slot.ctx);
}

int main(int argc, char **argv)
{
    if (argc != 2) { fprintf(stderr, "usage: %s owned|output|ctx|retain\n", argv[0]); return 64; }
    if (strcmp(argv[1], "owned") == 0) {
        struct record *owner = malloc(sizeof *owner);
        if (owner == NULL) return 2;
        owner->value = 4;
        consume_borrowed_and_free(owner);
        printf("owner_after=%d\n", owner->value);
        return 0;
    }
    if (strcmp(argv[1], "output") == 0) {
        struct frame *f = NULL;
        fail_after_publish = 1;
        printf("create_rc=%d\n", frame_create(8U, &f));
        printf("output_null=%s\n", f == NULL ? "yes" : "no");
        if (f != NULL) printf("len=%zu\n", f->len);
        return 0;
    }
    if (strcmp(argv[1], "ctx") == 0) return run_dangling_ctx();
    if (strcmp(argv[1], "retain") == 0) {
        struct retained_ctx c = {NULL, 0};
        struct record r = {9};
        (void)retain_cb(&r, &c);
        printf("retained=%s total=%d\n", c.last != NULL ? "yes" : "no", c.total);
        return 0;
    }
    return 64;
}
