#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

static int write_all(int fd, const char *buf, size_t len)
{
    size_t off = 0;
    while (off < len) {
        ssize_t n = write(fd, buf + off, len - off);
        if (n > 0) { off += (size_t)n; continue; }
        if (n < 0 && errno == EINTR) continue;
        return -1;
    }
    return 0;
}

int main(void)
{
    static const char payload[] = "alpha\nbeta\ngamma\n";
    const int slow = getenv("GATE_SLOW") != NULL;
    const struct timespec delay = {.tv_sec = 0, .tv_nsec = 100000000L};
    size_t rounds = slow ? 100U : 1U;
    for (size_t i = 0; i < rounds; ++i) {
        if (write_all(STDOUT_FILENO, payload, sizeof payload - 1U) != 0) return 2;
        if (slow) (void)nanosleep(&delay, NULL);
    }
    return 0;
}
