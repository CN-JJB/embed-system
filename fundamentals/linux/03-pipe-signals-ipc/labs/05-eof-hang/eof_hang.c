
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static int reader_loop(int fd)
{
    char buf[64];
    for (;;) {
        ssize_t n = read(fd, buf, sizeof buf);
        if (n > 0) continue;
        if (n == 0) {
            dprintf(STDOUT_FILENO, "reader: EOF\n");
            return 0;
        }
        if (errno == EINTR) continue;
        return 2;
    }
}

int main(int argc, char **argv)
{
    int p[2];
    pid_t child;
    int seeded = argc == 2 && strcmp(argv[1], "--seeded") == 0;
    int status;

    if (pipe(p) != 0) { perror("pipe"); return 1; }
    child = fork();
    if (child < 0) { perror("fork"); close(p[0]); close(p[1]); return 1; }

    if (child == 0) {
        int rc;
        close(p[1]);
        rc = reader_loop(p[0]);
        close(p[0]);
        _exit(rc);
    }

    close(p[0]);
    printf("parent_pid=%ld child_pid=%ld\n", (long)getpid(), (long)child);
    fflush(stdout);

    if (seeded) {
        puts("seeded: parent still holds write end; inspect /proc, then press Enter");
        fflush(stdout);
        (void)getchar();
    }
    close(p[1]);

    if (waitpid(child, &status, 0) < 0) { perror("waitpid"); return 1; }
    return WIFEXITED(status) && WEXITSTATUS(status) == 0 ? 0 : 1;
}
