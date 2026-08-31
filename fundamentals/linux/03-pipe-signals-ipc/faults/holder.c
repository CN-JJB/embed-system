
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <time.h>
#include <unistd.h>

int main(void)
{
    struct timespec ts = {1, 0};
    printf("holder_pid=%ld\n", (long)getpid());
    fflush(stdout);
    nanosleep(&ts, NULL);
    return 0;
}
