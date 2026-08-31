#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv)
{
    printf("RUN_ONE_TOKEN=%s argc=%d\n", getenv("RUN_ONE_TOKEN") ? getenv("RUN_ONE_TOKEN") : "<unset>", argc);
    return argc > 1 ? atoi(argv[1]) : 0;
}
