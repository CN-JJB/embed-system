
#include <errno.h>
#include <string.h>
#include <unistd.h>

static int write_all(int fd, const char *s, size_t n)
{
    size_t off = 0;
    while (off < n) {
        ssize_t r = write(fd, s + off, n - off);
        if (r > 0) { off += (size_t)r; continue; }
        if (r < 0 && errno == EINTR) continue;
        return -1;
    }
    return 0;
}

int main(void)
{
    static const char data[] = "alpha\nbeta\ngamma\n";
    return write_all(STDOUT_FILENO, data, sizeof data - 1) == 0 ? 0 : 1;
}
