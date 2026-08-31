#include "fdcopy_limit.h"

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int parse_limit(const char *s, uintmax_t *out)
{
    char *end = NULL;
    if (s == NULL || out == NULL || *s == '\0' || *s == '-') return -1;

    errno = 0;
    uintmax_t v = strtoumax(s, &end, 10);
    if (errno == ERANGE || end == s || *end != '\0') return -1;

    *out = v;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 5 || strcmp(argv[1], "--limit") != 0) {
        fprintf(stderr, "usage: %s --limit N INPUT OUTPUT\n", argv[0]);
        return 2;
    }

    uintmax_t limit;
    if (parse_limit(argv[2], &limit) < 0) {
        fprintf(stderr, "invalid limit: %s\n", argv[2]);
        return 2;
    }

    int in_fd = STDIN_FILENO, out_fd = STDOUT_FILENO;
    int own_in = 0, own_out = 0, status = 0;
    if (strcmp(argv[3], "-") != 0) {
        in_fd = open(argv[3], O_RDONLY);
        if (in_fd < 0) { perror("open input"); return 1; }
        own_in = 1;
    }
    if (strcmp(argv[4], "-") != 0) {
        out_fd = open(argv[4], O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (out_fd < 0) {
            int saved = errno;
            if (own_in) (void)close(in_fd);
            errno = saved; perror("open output"); return 1;
        }
        own_out = 1;
    }

    uintmax_t copied = 0;
    if (copy_fd_limit(in_fd, out_fd, limit, &copied) < 0) {
        int saved = errno;
        fprintf(stderr, "copy failed after %" PRIuMAX " bytes: %s\n",
                copied, strerror(saved));
        status = 1;
    }
    if (own_in && close(in_fd) < 0) { perror("close input"); status = 1; }
    if (own_out && close(out_fd) < 0) { perror("close output"); status = 1; }
    return status;
}
