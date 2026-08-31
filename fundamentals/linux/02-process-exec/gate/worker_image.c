#define _POSIX_C_SOURCE 200809L
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main(int argc, char **argv)
{
    int code = argc > 1 ? atoi(argv[1]) : 0;
    const char *fd_s = getenv("SUPERVISOR_FD");
    int fd = fd_s ? atoi(fd_s) : -1;
    int inherited = fd >= 0 && fcntl(fd, F_GETFD) != -1;
    printf("worker pid=%ld exit=%d supervisor_fd=%d inherited=%s\n",
           (long)getpid(), code, fd, inherited ? "yes" : "no");
    fflush(stdout);
    if (inherited) dprintf(fd, "worker %ld inherited supervisor fd %d\n", (long)getpid(), fd);
    return code;
}
