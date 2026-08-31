#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

int main(void)
{
    printf("before fork pid=%ld ppid=%ld\n", (long)getpid(), (long)getppid());
    fflush(stdout);

    pid_t r = fork();
    if (r == -1) { perror("fork"); return 1; }
    if (r == 0) {
        printf("child: fork_return=%ld pid=%ld ppid=%ld\n", (long)r, (long)getpid(), (long)getppid());
        fflush(stdout);
        _exit(7);
    }

    printf("parent: fork_return=%ld pid=%ld child=%ld\n", (long)r, (long)getpid(), (long)r);
    fflush(stdout);
    int status;
    if (waitpid(r, &status, 0) == -1) { perror("waitpid"); return 1; }
    if (WIFEXITED(status)) printf("parent: child exit=%d\n", WEXITSTATUS(status));
    return 0;
}
