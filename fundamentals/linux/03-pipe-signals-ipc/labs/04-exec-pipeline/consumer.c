
#include <errno.h>
#include <stdio.h>
#include <unistd.h>

int main(void)
{
    char buf[64];
    unsigned long bytes = 0;
    unsigned long lines = 0;
    for (;;) {
        ssize_t n = read(STDIN_FILENO, buf, sizeof buf);
        ssize_t i;
        if (n > 0) {
            bytes += (unsigned long)n;
            for (i = 0; i < n; i++) if (buf[i] == '\n') lines++;
            continue;
        }
        if (n == 0) break;
        if (errno == EINTR) continue;
        perror("consumer read");
        return 2;
    }
    printf("consumer bytes=%lu lines=%lu\n", bytes, lines);
    return 0;
}
