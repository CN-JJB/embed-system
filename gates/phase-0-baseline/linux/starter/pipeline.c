#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    if (argc != 3) {
        fprintf(stderr, "usage: %s PRODUCER FILTER\n", argv[0]);
        return 2;
    }

    (void)errno;
    (void)strerror;
    (void)fork;
    (void)pipe;
    (void)dup2;
    (void)execv;

    fputs("TODO: implement fork/pipe/dup2/exec/waitpid pipeline\n", stderr);
    return 2;
}
