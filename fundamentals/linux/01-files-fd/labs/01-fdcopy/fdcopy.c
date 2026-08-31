#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int write_all(int fd, const uint8_t *buf, size_t len)
{
    size_t off = 0;
    while (off < len) {
        ssize_t n = write(fd, buf + off, len - off);
        if (n > 0) {
            off += (size_t)n;
            continue;
        }
        if (n < 0 && errno == EINTR) continue;
        if (n == 0) errno = EIO;
        return -1;
    }
    return 0;
}

static int copy_fd(int in_fd, int out_fd)
{
    uint8_t buf[4096];
    for (;;) {
        ssize_t n = read(in_fd, buf, sizeof buf);
        if (n > 0) {
            if (write_all(out_fd, buf, (size_t)n) < 0) return -1;
            continue;
        }
        if (n == 0) return 0;
        if (errno == EINTR) continue;
        return -1;
    }
}

static void report_saved(const char *what, int saved_errno)
{
    fprintf(stderr, "%s: %s\n", what, strerror(saved_errno));
}

int main(int argc, char **argv)
{
    int in_fd = STDIN_FILENO;
    int out_fd = STDOUT_FILENO;
    int own_in = 0;
    int own_out = 0;
    int status = 0;

    if (argc != 3) {
        fprintf(stderr, "usage: %s INPUT OUTPUT\n       use - for stdin/stdout\n", argv[0]);
        return 2;
    }

    if (strcmp(argv[1], "-") != 0) {
        in_fd = open(argv[1], O_RDONLY);
        if (in_fd < 0) {
            perror("open input");
            return 1;
        }
        own_in = 1;
    }

    if (strcmp(argv[2], "-") != 0) {
        out_fd = open(argv[2], O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (out_fd < 0) {
            int saved = errno;
            if (own_in && close(in_fd) < 0)
                perror("close input after output-open failure");
            report_saved("open output", saved);
            return 1;
        }
        own_out = 1;
    }

    if (copy_fd(in_fd, out_fd) < 0) {
        int saved = errno;
        report_saved("copy", saved);
        status = 1;
    }

    if (own_in && close(in_fd) < 0) {
        perror("close input");
        status = 1;
    }
    if (own_out && close(out_fd) < 0) {
        perror("close output");
        status = 1;
    }
    return status;
}
