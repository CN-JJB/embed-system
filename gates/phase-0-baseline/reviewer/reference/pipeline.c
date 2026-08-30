#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static void child_fail(const char *what)
{
    fprintf(stderr, "%s: %s\n", what, strerror(errno));
    _exit(127);
}

static int child_ok(int status)
{
    return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

int main(int argc, char **argv)
{
    if (argc != 3) {
        fprintf(stderr, "usage: %s PRODUCER FILTER\n", argv[0]);
        return 2;
    }

    int p[2];
    if (pipe(p) == -1) {
        perror("pipe");
        return 1;
    }

    pid_t producer = fork();
    if (producer == -1) {
        perror("fork producer");
        close(p[0]);
        close(p[1]);
        return 1;
    }
    if (producer == 0) {
        if (dup2(p[1], STDOUT_FILENO) == -1) {
            child_fail("dup2 producer");
        }
        close(p[0]);
        close(p[1]);
        execl(argv[1], argv[1], (char *)NULL);
        child_fail("exec producer");
    }

    pid_t filter = fork();
    if (filter == -1) {
        perror("fork filter");
        close(p[0]);
        close(p[1]);
        (void)waitpid(producer, NULL, 0);
        return 1;
    }
    if (filter == 0) {
        if (dup2(p[0], STDIN_FILENO) == -1) {
            child_fail("dup2 filter");
        }
        close(p[0]);
        close(p[1]);
        execl(argv[2], argv[2], (char *)NULL);
        child_fail("exec filter");
    }

    close(p[0]);
    close(p[1]);

    int ps = 0;
    int fs = 0;
    if (waitpid(producer, &ps, 0) == -1) {
        perror("waitpid producer");
        return 1;
    }
    if (waitpid(filter, &fs, 0) == -1) {
        perror("waitpid filter");
        return 1;
    }

    return child_ok(ps) && child_ok(fs) ? 0 : 1;
}
