
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

static int write_all(int fd, const void *buf, size_t len)
{
    const char *p = buf;
    size_t off = 0;
    while (off < len) {
        ssize_t n = write(fd, p + off, len - off);
        if (n > 0) { off += (size_t)n; continue; }
        if (n < 0 && errno == EINTR) continue;
        return -1;
    }
    return 0;
}

int main(void)
{
    int p[2];
    pid_t child;
    int status;

    if (pipe(p) != 0) { perror("pipe"); return 1; }
    child = fork();
    if (child < 0) {
        perror("fork");
        close(p[0]); close(p[1]);
        return 1;
    }
    if (child == 0) {
        char buf[64];
        ssize_t n;
        close(p[1]);
        while ((n = read(p[0], buf, sizeof buf)) > 0) {
            if (write_all(STDOUT_FILENO, buf, (size_t)n) != 0) _exit(2);
        }
        close(p[0]);
        _exit(n == 0 ? 0 : 3);
    }

    close(p[0]);
    if (write_all(p[1], "parent->child\n", 14) != 0) {
        perror("write");
    }
    close(p[1]);
    if (waitpid(child, &status, 0) < 0) { perror("waitpid"); return 1; }
    if (WIFEXITED(status)) {
        printf("child_exit=%d\n", WEXITSTATUS(status));
        return WEXITSTATUS(status) == 0 ? 0 : 1;
    }
    return 1;
}
