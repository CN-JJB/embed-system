#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(void)
{
    enum { CHILDREN = 5 };

    printf("parent pid=%ld\n", (long)getpid());
    fflush(stdout);

    for (int i = 0; i < CHILDREN; ++i) {
        int p[2];
        if (pipe(p) == -1) {
            perror("pipe");
            return 1;
        }

        pid_t pid = fork();
        if (pid == -1) {
            perror("fork");
            return 1;
        }

        if (pid == 0) {
            char byte = (char)('A' + i);
            close(p[0]);
            if (write(p[1], &byte, 1) != 1) {
                _exit(2);
            }
            close(p[1]);
            _exit(0);
        }

        char byte = '?';
        if (read(p[0], &byte, 1) != 1) {
            fprintf(stderr, "read failed: %s\n", strerror(errno));
        }
        printf("child=%ld byte=%c\n", (long)pid, byte);

        /* Intentionally missing parent-side close() calls and waitpid(). */
    }

    puts("inspection window open; terminate this process when finished");
    fflush(stdout);

    for (;;) {
        pause();
    }
}
