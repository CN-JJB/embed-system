
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static int reader(int fd)
{
    char buf[64];
    for (;;) {
        ssize_t n = read(fd, buf, sizeof buf);
        if (n > 0) continue;
        if (n == 0) {
            dprintf(STDOUT_FILENO, "reader EOF\n");
            return 0;
        }
        if (errno == EINTR) continue;
        return 2;
    }
}

static int extra_parent(void)
{
    int p[2], st;
    pid_t child;
    if (pipe(p) != 0) return 1;
    child = fork();
    if (child < 0) return 1;
    if (child == 0) {
        int rc;
        close(p[1]);
        rc = reader(p[0]);
        close(p[0]);
        _exit(rc);
    }
    close(p[0]);
    printf("parent=%ld reader=%ld; inspect FDs, then Enter\n",
           (long)getpid(), (long)child);
    fflush(stdout);
    (void)getchar(); /* parent still retains p[1] */
    close(p[1]);
    if (waitpid(child, &st, 0) < 0) return 1;
    return 0;
}

static int inherited_exec(void)
{
    int p[2], st;
    pid_t r, h;
    if (pipe(p) != 0) return 1;
    r = fork();
    if (r < 0) return 1;
    if (r == 0) {
        int rc;
        close(p[1]);
        rc = reader(p[0]);
        close(p[0]);
        _exit(rc);
    }
    close(p[0]);

    h = fork();
    if (h < 0) {
        close(p[1]);
        waitpid(r, NULL, 0);
        return 1;
    }
    if (h == 0) {
        execl("./holder", "holder", (char *)NULL);
        _exit(127);
    }

    printf("reader=%ld holder=%ld; holder inherited write end across exec\n",
           (long)r, (long)h);
    fflush(stdout);
    close(p[1]);
    waitpid(h, &st, 0);
    waitpid(r, &st, 0);
    return 0;
}

static int wrong_dup2(void)
{
    int p[2], st;
    pid_t c;
    if (pipe(p) != 0) return 1;
    c = fork();
    if (c < 0) return 1;
    if (c == 0) {
        ssize_t n;
        close(p[1]);
        if (dup2(p[0], STDOUT_FILENO) < 0) _exit(120);
        if (p[0] != STDOUT_FILENO) close(p[0]);
        errno = 0;
        n = write(STDOUT_FILENO, "x", 1);
        dprintf(STDERR_FILENO, "write_via_wrong_endpoint=%zd errno=%d\n", n, errno);
        _exit(n < 0 ? 0 : 2);
    }
    close(p[0]); close(p[1]);
    waitpid(c, &st, 0);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "usage: %s extra-parent|inherited-exec|wrong-dup2\n", argv[0]);
        return 64;
    }
    if (strcmp(argv[1], "extra-parent") == 0) return extra_parent();
    if (strcmp(argv[1], "inherited-exec") == 0) return inherited_exec();
    if (strcmp(argv[1], "wrong-dup2") == 0) return wrong_dup2();
    return 64;
}
