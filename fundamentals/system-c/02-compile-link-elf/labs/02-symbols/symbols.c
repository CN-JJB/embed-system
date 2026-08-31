#include "symbols.h"

int external_global = 7;
static int file_static_global = 3;

static int static_helper(int value)
{
    return value + file_static_global;
}

int public_add(int value)
{
    return static_helper(value) + external_global;
}

int public_probe(void)
{
    return file_static_global;
}
