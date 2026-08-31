#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>
int main(void)
{
    int local_only = 99;
    if (setenv("DEMO_COLOR", "green-from-parent-environment", 1) == -1) { perror("setenv"); return 1; }
    printf("parent pid=%ld local_only=%d DEMO_COLOR=%s\n", (long)getpid(), local_only, getenv("DEMO_COLOR"));
    fflush(stdout);
    pid_t child = fork();
    if (child == -1) { perror("fork"); return 1; }
    if (child == 0) {
        char *const argv[] = {"env_image", NULL};
        execv("./env_image", argv);
        perror("execv");
        _exit(127);
    }
    int status;
    if (waitpid(child, &status, 0) == -1) { perror("waitpid"); return 1; }
    return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
}
