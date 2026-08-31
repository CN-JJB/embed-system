#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int fault_leak(const char *path)
{
    int fds[3];
    printf("pid=%ld\n", (long)getpid());
    for (size_t i = 0; i < 3; ++i) {
        fds[i] = open(path, O_RDONLY);
        if (fds[i] < 0) { perror("open"); return 1; }
        printf("opened fd=%d\n", fds[i]);
    }
    puts("inspect /proc/<pid>/fd now; press Enter to exit");
    fflush(stdout);
    (void)getchar();
    /* deliberate leak: no close */
    return 0;
}

static int borrowed_reader_bug(int fd)
{
    char c;
    ssize_t n = read(fd, &c, 1);
    if (n < 0) return -1;
    if (close(fd) < 0) return -1; /* fault: fd was borrowed */
    return 0;
}

static int fault_ownership(const char *path)
{
    int fd = open(path, O_RDONLY);
    if (fd < 0) { perror("open"); return 1; }
    if (borrowed_reader_bug(fd) < 0) { perror("helper"); close(fd); return 1; }
    char c;
    ssize_t n = read(fd, &c, 1);
    if (n < 0) {
        fprintf(stderr, "caller read after helper: errno=%d (%s)\n", errno, strerror(errno));
        return 1;
    }
    close(fd);
    return 0;
}

static ssize_t capped_write(int fd, const void *buf, size_t count)
{
    size_t cap = count > 3 ? 3 : count;
    return write(fd, buf, cap);
}

static int fault_short_write(const char *input, const char *output)
{
    int in_fd = open(input, O_RDONLY);
    if (in_fd < 0) { perror("open input"); return 1; }
    int out_fd = open(output, O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (out_fd < 0) { perror("open output"); close(in_fd); return 1; }

    uint8_t buf[16];
    ssize_t n;
    while ((n = read(in_fd, buf, sizeof buf)) > 0) {
        ssize_t wr = capped_write(out_fd, buf, (size_t)n);
        if (wr < 0) { perror("write"); close(in_fd); close(out_fd); return 1; }
        /* fault: any positive write is incorrectly treated as complete */
    }
    if (n < 0) perror("read");
    close(in_fd); close(out_fd);
    return n < 0 ? 1 : 0;
}

static int fault_error_propagation(const char *path)
{
    int fd = open(path, O_RDONLY);
    if (fd >= 0) { close(fd); fprintf(stderr, "expected open failure for this setup\n"); return 2; }

    (void)close(fd); /* fault: close(-1) overwrites the original errno with EBADF */
    fprintf(stderr, "reported open error: errno=%d (%s)\n", errno, strerror(errno));
    return 1;
}

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "usage: %s leak PATH | ownership PATH | short INPUT OUTPUT | propagation PATH\n", argv[0]);
        return 2;
    }
    if (strcmp(argv[1], "leak") == 0 && argc == 3) return fault_leak(argv[2]);
    if (strcmp(argv[1], "ownership") == 0 && argc == 3) return fault_ownership(argv[2]);
    if (strcmp(argv[1], "short") == 0 && argc == 4) return fault_short_write(argv[2], argv[3]);
    if (strcmp(argv[1], "propagation") == 0 && argc == 3) return fault_error_propagation(argv[2]);
    return 2;
}
