#include "symbols.h"

#include <stdio.h>

int main(void)
{
    printf("value=%d probe=%d global=%d\n", public_add(5), public_probe(), external_global);
    return 0;
}
