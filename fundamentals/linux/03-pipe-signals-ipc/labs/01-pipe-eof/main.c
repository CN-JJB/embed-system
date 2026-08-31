
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int write_all(int fd, const void *buf, size_t len)
{
    const unsigned char *p = buf;
    size_t off = 0;
    while (off < len) {
        ssize_t n = write(fd, p + off, len - off);
        if (n > 0) {
            off += (size_t)n;
            continue;
        }
        if (n < 0 && errno == EINTR) continue;
        return -1;
    }
    return 0;
}

int main(void)
{
    int p[2];
    char buf[32];
    ssize_t n;

    if (pipe(p) != 0) {
        perror("pipe");
        return 1;
    }
    if (write_all(p[1], "abc", 3) != 0) {
        perror("write");
        close(p[0]);
        close(p[1]);
        return 1;
    }
    if (close(p[1]) != 0) {
        perror("close write");
        close(p[0]);
        return 1;
    }

    n = read(p[0], buf, sizeof buf);
    if (n < 0) {
        perror("read data");
        close(p[0]);
        return 1;
    }
    printf("first_read=%zd bytes\n", n);

    n = read(p[0], buf, sizeof buf);
    if (n < 0) {
        perror("read eof");
        close(p[0]);
        return 1;
    }
    printf("second_read=%zd (EOF when zero)\n", n);
    close(p[0]);
    return n == 0 ? 0 : 1;
}
