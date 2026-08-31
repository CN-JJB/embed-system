#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <stdio.h>
#include <unistd.h>

int main(void)
{
    char buf[128];
    size_t bytes = 0;
    size_t lines = 0;

    for (;;) {
        ssize_t n = read(STDIN_FILENO, buf, sizeof buf);
        if (n > 0) {
            bytes += (size_t)n;
            for (ssize_t i = 0; i < n; ++i) {
                if (buf[i] == '\n') {
                    ++lines;
                }
            }
            continue;
        }
        if (n == 0) break;
        if (errno == EINTR) continue;
        perror("consumer read");
        return 2;
    }
    printf("consumer: bytes=%zu lines=%zu EOF=yes\n", bytes, lines);
    return 0;
}
