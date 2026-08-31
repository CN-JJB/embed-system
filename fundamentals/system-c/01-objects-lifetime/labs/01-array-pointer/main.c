#include <stdio.h>

static void inspect_parameter(int a[10])
{
    printf("inside f: sizeof(a)      = %zu\n", sizeof a);
    printf("inside f: a value        = %p\n", (void *)a);
    printf("inside f: &a param object= %p\n", (void *)&a);
}

int main(void)
{
    int array[10] = {0};
    int *pointer = array;

    printf("main: sizeof(array)      = %zu\n", sizeof array);
    printf("main: sizeof(pointer)    = %zu\n", sizeof pointer);
    printf("main: array value        = %p\n", (void *)array);
    printf("main: &array             = %p\n", (void *)&array);
    printf("main: &pointer           = %p\n", (void *)&pointer);

    inspect_parameter(array);
    return 0;
}
