#include "../challenge/fdcopy_limit.h"

#include <errno.h>
#include <stdint.h>
#include <unistd.h>

static int write_all(int fd, const uint8_t *buf, size_t len)
{
    size_t off = 0;
    while (off < len) {
        ssize_t n = write(fd, buf + off, len - off);
        if (n > 0) { off += (size_t)n; continue; }
        if (n < 0 && errno == EINTR) continue;
        if (n == 0) errno = EIO;
        return -1;
    }
    return 0;
}

int copy_fd_limit(int in_fd, int out_fd, uintmax_t limit, uintmax_t *copied)
{
    uint8_t buf[4096];
    if (copied == NULL) { errno = EINVAL; return -1; }
    *copied = 0;

    while (*copied < limit) {
        uintmax_t remaining = limit - *copied;
        size_t want = remaining < (uintmax_t)sizeof buf ? (size_t)remaining : sizeof buf;
        ssize_t n = read(in_fd, buf, want);
        if (n > 0) {
            if (write_all(out_fd, buf, (size_t)n) < 0) return -1;
            *copied += (uintmax_t)n;
            continue;
        }
        if (n == 0) return 0;
        if (errno == EINTR) continue;
        return -1;
    }
    return 0;
}
