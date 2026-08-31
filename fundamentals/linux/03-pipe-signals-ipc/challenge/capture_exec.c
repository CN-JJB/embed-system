
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <stdio.h>

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "usage: %s COMMAND [ARGS...]\n", argv[0]);
        return 64;
    }
    (void)argv;
    errno = ENOSYS;
    perror("capture_exec TODO");
    return 1;
}
