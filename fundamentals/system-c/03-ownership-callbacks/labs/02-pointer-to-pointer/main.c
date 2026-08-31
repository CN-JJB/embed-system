#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct frame { size_t len; unsigned char *data; };
static int fail_next_allocation;

static void *lab_malloc(size_t n)
{
    if (fail_next_allocation) { fail_next_allocation = 0; return NULL; }
    return malloc(n);
}

static int frame_create(size_t len, struct frame **out)
{
    struct frame *f;
    if (out == NULL || *out != NULL || len == 0) return EINVAL;
    f = lab_malloc(sizeof *f);
    if (f == NULL) return ENOMEM;
    f->data = malloc(len);
    if (f->data == NULL) { free(f); return ENOMEM; }
    memset(f->data, 0, len);
    f->len = len;
    *out = f;
    return 0;
}

static void frame_destroy(struct frame **p)
{
    if (p == NULL || *p == NULL) return;
    free((*p)->data);
    (*p)->data = NULL;
    free(*p);
    *p = NULL;
}

int main(void)
{
    struct frame *f = NULL;
    int rc = frame_create(16, &f);
    printf("success rc=%d nonnull=%s len=%zu\n", rc, f != NULL ? "yes" : "no", f ? f->len : 0U);
    frame_destroy(&f);
    frame_destroy(&f);
    fail_next_allocation = 1;
    rc = frame_create(16, &f);
    printf("failure rc=%d output_null=%s\n", rc, f == NULL ? "yes" : "no");
    return rc == ENOMEM && f == NULL ? 0 : 1;
}
