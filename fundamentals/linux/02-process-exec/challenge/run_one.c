#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static int apply_override(const char *text)
{
    const char *eq = strchr(text, '=');
    if (!eq || eq == text) return -1;
    size_t n = (size_t)(eq - text);
    char *name = malloc(n + 1);
    if (!name) return -1;
    memcpy(name, text, n);
    name[n] = '\0';
    int rc = setenv(name, eq + 1, 1);
    free(name);
    return rc;
}

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "usage: %s NAME=VALUE COMMAND [ARGS...]\n", argv[0]);
        return 2;
    }
    /* TODO learner: fork, child override+exec, parent waitpid+decode. */
    (void)apply_override;
    (void)errno;
    fputs("TODO: implement run_one without system()/popen()\n", stderr);
    return 2;
}
