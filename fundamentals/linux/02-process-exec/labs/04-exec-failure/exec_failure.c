#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static int try_exec_bad(const char *path)
{
    char *const argv[] = {(char *)path, NULL};
    execv(path, argv);
    perror("execv");
    return 127; /* deliberate fall-through bug when caller keeps running */
}

int main(int argc, char **argv)
{
    const char *path = argc > 1 ? argv[1] : "./does-not-exist";
    int bad_mode = argc > 2 && strcmp(argv[2], "--bad-return") == 0;
    pid_t child = fork();
    if (child == -1) { perror("fork"); return 1; }
    if (child == 0) {
        if (bad_mode) {
            int rc = try_exec_bad(path);
            printf("BUG: child continued in caller after exec failure rc=%d pid=%ld\n", rc, (long)getpid());
            return rc;
        }
        char *const child_argv[] = {(char *)path, NULL};
        execv(path, child_argv);
        perror("execv");
        _exit(127);
    }

    int status;
    if (waitpid(child, &status, 0) == -1) { perror("waitpid"); return 1; }
    if (WIFEXITED(status)) printf("parent observed exit=%d\n", WEXITSTATUS(status));
    return 0;
}
