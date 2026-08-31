#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    printf("child_image: pid=%ld ppid=%ld argc=%d token=%s\n", (long)getpid(), (long)getppid(), argc,
           getenv("M04_TOKEN") ? getenv("M04_TOKEN") : "<unset>");
    for (int i = 0; i < argc; ++i) printf("argv[%d]=%s\n", i, argv[i]);
    fflush(stdout);
    return 23;
}
