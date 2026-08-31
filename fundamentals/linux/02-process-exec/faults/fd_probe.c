#define _POSIX_C_SOURCE 200809L
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main(void)
{
    const char *s = getenv("FAULT_FD");
    if (!s) return 2;
    int fd = atoi(s);
    int open_now = fcntl(fd, F_GETFD) != -1;
    printf("fd_probe pid=%ld fd=%d inherited_open=%s\n", (long)getpid(), fd, open_now ? "yes" : "no");
    if (open_now) dprintf(fd, "unexpected inherited writer pid=%ld\n", (long)getpid());
    return open_now ? 9 : 0;
}
