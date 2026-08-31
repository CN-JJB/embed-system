#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static size_t injected_cap(size_t requested)
{
    const char *s = getenv("LOG_COPY_WRITE_CAP");
    if (s == NULL || *s == '\0') return requested;
    char *end = NULL;
    errno = 0;
    unsigned long v = strtoul(s, &end, 10);
    if (errno != 0 || end == s || *end != '\0' || v == 0) return requested;
    return v < requested ? (size_t)v : requested;
}

static ssize_t testable_write(int fd, const void *buf, size_t count)
{
    return write(fd, buf, injected_cap(count));
}

static int write_all(int fd, const uint8_t *buf, size_t len)
{
    size_t off = 0;
    while (off < len) {
        ssize_t n = testable_write(fd, buf + off, len - off);
        if (n > 0) { off += (size_t)n; continue; }
        if (n < 0 && errno == EINTR) continue;
        if (n == 0) errno = EIO;
        return -1;
    }
    return 0;
}

/* Contract: both descriptors are borrowed. */
static int copy_payload(int in_fd, int out_fd)
{
    uint8_t buf[32];
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

static int copy_one(const char *input, const char *output)
{
    int in_fd = open(input, O_RDONLY);
    if (in_fd < 0) { perror("open input"); return -1; }

    int out_fd = open(output, O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (out_fd < 0) {
        int saved = errno;
        if (close(in_fd) < 0) perror("close input after output-open failure");
        errno = saved;
        perror("open output");
        return -1;
    }

    int rc = copy_payload(in_fd, out_fd);
    int saved = errno;
    int cleanup_failed = 0;
    if (close(in_fd) < 0) { perror("close input"); cleanup_failed = 1; }
    if (close(out_fd) < 0) { perror("close output"); cleanup_failed = 1; }

    if (rc < 0) {
        errno = saved;
        perror("copy payload");
        return -1;
    }
    return cleanup_failed ? -1 : 0;
}

static int leak_demo(const char *input, const char *bad_output)
{
    printf("pid=%ld\n", (long)getpid());
    for (int i = 0; i < 3; ++i) (void)copy_one(input, bad_output);
    puts("inspect /proc/<pid>/fd now; press Enter to exit");
    fflush(stdout);
    (void)getchar();
    return 1;
}

int main(int argc, char **argv)
{
    if (argc == 4 && strcmp(argv[1], "--leak-demo") == 0)
        return leak_demo(argv[2], argv[3]);
    if (argc == 3) return copy_one(argv[1], argv[2]) == 0 ? 0 : 1;
    return 2;
}
