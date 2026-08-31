#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct item { int value; };
struct holder { const struct item *retained; };
struct callback_slot { void (*fn)(const struct item *, struct holder *); struct holder *ctx; };
static int fail_second;

static void free_borrowed(const struct item *borrowed) { free((void *)borrowed); }

static int make_broken(struct item **out)
{
    struct item *p;
    if (out == NULL || *out != NULL) return EINVAL;
    p = malloc(sizeof *p);
    if (p == NULL) return ENOMEM;
    *out = p;
    if (fail_second) { free(p); return EIO; }
    p->value = 9;
    return 0;
}

static void retain_forbidden(const struct item *borrowed, struct holder *h)
{
    h->retained = borrowed;
}

static void release_holder(struct holder **p)
{
    if (p != NULL && *p != NULL) { free(*p); *p = NULL; }
}

static int dangling_ctx_case(void)
{
    struct holder *ctx = malloc(sizeof *ctx);
    struct callback_slot slot;
    struct item item = {1};
    if (ctx == NULL) return 2;
    ctx->retained = NULL;
    slot.fn = retain_forbidden;
    slot.ctx = ctx;
    release_holder(&ctx);
    slot.fn(&item, slot.ctx);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2) { fprintf(stderr, "usage: %s borrowed-free|dangling-ctx|broken-out|retain\n", argv[0]); return 64; }
    if (strcmp(argv[1], "borrowed-free") == 0) {
        struct item *owner = malloc(sizeof *owner);
        if (owner == NULL) return 2;
        owner->value = 3;
        free_borrowed(owner);
        printf("owner_later=%d\n", owner->value);
        return 0;
    }
    if (strcmp(argv[1], "dangling-ctx") == 0) return dangling_ctx_case();
    if (strcmp(argv[1], "broken-out") == 0) {
        struct item *out = NULL;
        fail_second = 1;
        printf("rc=%d\n", make_broken(&out));
        printf("failure_output_nonnull=%s\n", out != NULL ? "yes" : "no");
        if (out != NULL) printf("dangling_value=%d\n", out->value);
        return 0;
    }
    if (strcmp(argv[1], "retain") == 0) {
        struct item item = {11};
        struct holder h = {NULL};
        retain_forbidden(&item, &h);
        printf("retained=%s current_value=%d\n", h.retained != NULL ? "yes" : "no", h.retained->value);
        return 0;
    }
    return 64;
}
