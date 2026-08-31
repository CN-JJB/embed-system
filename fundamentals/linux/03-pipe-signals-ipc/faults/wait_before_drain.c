
#include <errno.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

static int write_many(int fd)
{
    char block[4096] = {0};
    unsigned i;
    for (i = 0; i < 2048; i++) {
        size_t off = 0;
        while (off < sizeof block) {
            ssize_t n = write(fd, block + off, sizeof block - off);
            if (n > 0) { off += (size_t)n; continue; }
            if (n < 0 && errno == EINTR) continue;
            return 2;
        }
    }
    return 0;
}

int main(void)
{
    int p[2];
    pid_t child;
    int status;
    char buf[4096];

    if (pipe(p) != 0) return 1;
    child = fork();
    if (child < 0) return 1;
    if (child == 0) {
        int rc;
        close(p[0]);
        rc = write_many(p[1]);
        close(p[1]);
        _exit(rc);
    }

    close(p[1]);

    /* Seeded progress bug: parent waits before draining child output. */
    if (waitpid(child, &status, 0) < 0) return 1;

    while (read(p[0], buf, sizeof buf) > 0) { }
    close(p[0]);
    return 0;
}
