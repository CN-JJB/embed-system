#include <stdio.h>
#include <stdlib.h>

struct box { int value; };
static unsigned releases;

static struct box *box_create(int v)
{
    struct box *p = malloc(sizeof *p);
    if (p != NULL) p->value = v;
    return p;
}

static const struct box *box_borrow(const struct box *p) { return p; }
static struct box *box_take(struct box **owner)
{
    struct box *p;
    if (owner == NULL) return NULL;
    p = *owner;
    *owner = NULL;
    return p;
}
static void box_release(struct box *p)
{
    if (p != NULL) { ++releases; free(p); }
}

int main(void)
{
    struct box *caller_owned = box_create(7);
    const struct box *borrowed;
    struct box *transferred;
    if (caller_owned == NULL) return 1;
    borrowed = box_borrow(caller_owned);
    printf("borrowed_value=%d caller_still_owns=yes\n", borrowed->value);
    transferred = box_take(&caller_owned);
    printf("after_take caller_null=%s transferred_value=%d\n",
           caller_owned == NULL ? "yes" : "no", transferred->value);
    box_release(transferred);
    printf("release_count=%u\n", releases);
    return releases == 1U && caller_owned == NULL ? 0 : 1;
}
