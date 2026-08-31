
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static int write_all(int fd, const void *buf, size_t len)
{
    const unsigned char *p = buf;
    size_t off = 0;
    while (off < len) {
        ssize_t n = write(fd, p + off, len - off);
        if (n > 0) { off += (size_t)n; continue; }
        if (n < 0 && errno == EINTR) continue;
        return -1;
    }
    return 0;
}

int main(int argc, char **argv)
{
    int p[2];
    pid_t child;
    int status;
    int read_failed = 0;
    char buf[4096];

    if (argc < 2) {
        fprintf(stderr, "usage: %s COMMAND [ARGS...]\n", argv[0]);
        return 64;
    }
    if (pipe(p) != 0) { perror("pipe"); return 1; }

    child = fork();
    if (child < 0) {
        perror("fork");
        close(p[0]); close(p[1]);
        return 1;
    }

    if (child == 0) {
        close(p[0]);
        if (dup2(p[1], STDOUT_FILENO) < 0) {
            dprintf(STDERR_FILENO, "dup2: %s\n", strerror(errno));
            _exit(126);
        }
        if (p[1] != STDOUT_FILENO) close(p[1]);
        execvp(argv[1], &argv[1]);
        dprintf(STDERR_FILENO, "execvp %s: %s\n", argv[1], strerror(errno));
        _exit(127);
    }

    close(p[1]);
    for (;;) {
        ssize_t n = read(p[0], buf, sizeof buf);
        if (n > 0) {
            if (write_all(STDOUT_FILENO, buf, (size_t)n) != 0) {
                perror("capture output");
                read_failed = 1;
                break;
            }
            continue;
        }
        if (n == 0) break;
        if (errno == EINTR) continue;
        perror("read");
        read_failed = 1;
        break;
    }
    close(p[0]);

    while (waitpid(child, &status, 0) < 0) {
        if (errno == EINTR) continue;
        perror("waitpid");
        return 1;
    }

    if (WIFEXITED(status)) {
        dprintf(STDERR_FILENO, "child_exit=%d\n", WEXITSTATUS(status));
    } else if (WIFSIGNALED(status)) {
        dprintf(STDERR_FILENO, "child_signal=%d\n", WTERMSIG(status));
    }
    if (read_failed) return 1;
    return 0;
}
