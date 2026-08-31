
#include <errno.h>
#include <stdio.h>
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
    char buf[128];
    ssize_t n;

    if (pipe(p) != 0) { perror("pipe"); return 1; }
    child = fork();
    if (child < 0) { perror("fork"); close(p[0]); close(p[1]); return 1; }

    if (child == 0) {
        static const char msg[] = "fd1-now-pipe\n";
        close(p[0]);
        if (dup2(p[1], STDOUT_FILENO) < 0) _exit(120);
        if (p[1] != STDOUT_FILENO) close(p[1]);
        if (write_all(STDOUT_FILENO, msg, sizeof msg - 1) != 0) _exit(121);
        _exit(0);
    }

    close(p[1]);
    n = read(p[0], buf, sizeof buf);
    if (n < 0) { perror("read"); close(p[0]); waitpid(child, NULL, 0); return 1; }
    if (write_all(STDOUT_FILENO, buf, (size_t)n) != 0) {
        close(p[0]); waitpid(child, NULL, 0); return 1;
    }
    close(p[0]);

    if (waitpid(child, &status, 0) < 0) { perror("waitpid"); return 1; }
    return WIFEXITED(status) && WEXITSTATUS(status) == 0 ? 0 : 1;
}
