#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

int main(void)
{
    pid_t child = fork();
    if (child == -1) { perror("fork"); return 1; }
    if (child == 0) {
        printf("before exec: pid=%ld ppid=%ld\n", (long)getpid(), (long)getppid());
        fflush(stdout);
        char *const argv[] = {"child_image", "alpha", "beta", NULL};
        char *const envp[] = {"M04_TOKEN=from-explicit-envp", "PATH=/usr/bin:/bin", NULL};
        execve("./child_image", argv, envp);
        perror("execve");
        _exit(127);
    }

    printf("parent: pid=%ld child=%ld\n", (long)getpid(), (long)child);
    int status;
    if (waitpid(child, &status, 0) == -1) { perror("waitpid"); return 1; }
    if (WIFEXITED(status)) printf("parent: child exit=%d\n", WEXITSTATUS(status));
    return 0;
}
