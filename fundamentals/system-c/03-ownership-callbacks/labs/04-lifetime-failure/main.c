#include <stdio.h>
#include <stdlib.h>

struct record { int value; };
static const struct record *retained;
static void retain_borrowed(const struct record *r) { retained = r; }

static void produce_once(void)
{
    struct record *owned = malloc(sizeof *owned);
    if (owned == NULL) exit(2);
    owned->value = 42;
    retain_borrowed(owned);
    free(owned);
}

int main(void)
{
    produce_once();
    printf("later_value=%d\n", retained->value);
    return 0;
}
