#define _POSIX_C_SOURCE 200809L
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

static pid_t spawn_one(const char *path, const char *code, int log_fd)
{
    pid_t pid = fork();
    if (pid == -1) return -1;
    if (pid == 0) {
        close(log_fd);
        char *const av[] = {(char *)path, (char *)code, NULL};
        execv(path, av);
        perror("execv");
        _exit(127);
    }
    return pid;
}

static void report_status(pid_t pid, int st)
{
    if (WIFEXITED(st))
        printf("child %ld exited code=%d\n", (long)pid, WEXITSTATUS(st));
    else if (WIFSIGNALED(st))
        printf("child %ld signal=%d\n", (long)pid, WTERMSIG(st));
}

int main(void)
{
    int fd = open("supervisor.log", O_CREAT | O_TRUNC | O_WRONLY, 0644);
    if (fd < 0) { perror("open"); return 1; }

    char t[32];
    snprintf(t, sizeof t, "%d", fd);
    if (setenv("SUPERVISOR_FD", t, 1) == -1) {
        perror("setenv");
        close(fd);
        return 1;
    }

    pid_t a = spawn_one("./worker_image", "7", fd);
    if (a < 0) {
        perror("fork");
        close(fd);
        return 1;
    }

    pid_t b = spawn_one("./worker_missing", "3", fd);
    if (b < 0) {
        perror("fork");
        int sa;
        if (waitpid(a, &sa, 0) == -1) perror("waitpid");
        close(fd);
        return 1;
    }

    int sa = 0, sb = 0;
    int ok = 1;
    if (waitpid(a, &sa, 0) == -1) {
        perror("waitpid good");
        ok = 0;
    }
    if (waitpid(b, &sb, 0) == -1) {
        perror("waitpid missing");
        ok = 0;
    }

    if (ok) {
        report_status(a, sa);
        report_status(b, sb);
    }
    close(fd);
    return ok ? 0 : 1;
}
