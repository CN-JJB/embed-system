#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>
int main(void)
{
    if (setenv("INTEGRATION_TOKEN", "present", 1) == -1) { perror("setenv"); return 1; }
    pid_t child = fork();
    if (child == -1) { perror("fork"); return 1; }
    if (child == 0) {
        printf("parent image child-before-exec pid=%ld\n", (long)getpid());
        fflush(stdout);
        char *const argv[] = {"child_image", "from-parent", NULL};
        execv("./child_image", argv);
        perror("execv");
        _exit(127);
    }
    printf("parent pid=%ld child=%ld\n", (long)getpid(), (long)child);
    fflush(stdout);
    int status;
    if (waitpid(child, &status, 0) == -1) { perror("waitpid"); return 1; }
    return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
}
