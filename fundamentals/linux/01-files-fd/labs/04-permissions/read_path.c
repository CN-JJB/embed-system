#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    char byte;
    if (argc != 2) {
        fprintf(stderr, "usage: %s PATH\n", argv[0]);
        return 2;
    }

    int fd = open(argv[1], O_RDONLY);
    if (fd < 0) {
        int saved = errno;
        fprintf(stderr, "open %s failed: errno=%d (%s)\n",
                argv[1], saved, strerror(saved));
        return 1;
    }

    ssize_t n = read(fd, &byte, 1);
    if (n < 0) {
        int saved = errno;
        (void)close(fd);
        fprintf(stderr, "read failed: errno=%d (%s)\n", saved, strerror(saved));
        return 1;
    }
    printf("open succeeded; first read returned %zd\n", n);
    if (close(fd) < 0) {
        perror("close");
        return 1;
    }
    return 0;
}
