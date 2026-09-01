#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static uint32_t get_u32_le(const unsigned char *p)
{
    return (uint32_t)p[0] |
           ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) |
           ((uint32_t)p[3] << 24);
}

static int memory_mode(void)
{
    struct holder {
        int *value;
    } h = {0};

    h.value = malloc(sizeof *h.value);
    if (h.value == NULL) {
        perror("malloc");
        return 1;
    }

    *h.value = 99;
    printf("memory value=%d\n", *h.value);
    free(h.value);
    h.value = NULL;
    puts("memory regression: owner lifetime covers borrower access");
    return 0;
}

static int bytes_mode(void)
{
    const unsigned char bytes[4] = {0x78, 0x56, 0x34, 0x12};
    const uint32_t value = get_u32_le(bytes);

    printf("decoded=0x%08x contract=0x12345678\n", value);
    return value == UINT32_C(0x12345678) ? 0 : 1;
}

static int write_all(int fd, const unsigned char *buf, size_t n)
{
    size_t off = 0;

    while (off < n) {
        ssize_t nw = write(fd, buf + off, n - off);
        if (nw < 0) {
            if (errno == EINTR)
                continue;
            return -1;
        }
        off += (size_t)nw;
    }
    return 0;
}

static int child_read_to_eof(int fd)
{
    unsigned char buf[16];
    size_t total = 0;

    for (;;) {
        ssize_t nr = read(fd, buf, sizeof buf);
        if (nr < 0) {
            if (errno == EINTR)
                continue;
            return 1;
        }
        if (nr == 0)
            break;
        total += (size_t)nr;
    }

    return total == 3 ? 0 : 1;
}

static int fd_mode(void)
{
    int p[2];
    const unsigned char payload[3] = {'o', 'k', '\n'};

    if (pipe(p) < 0) {
        perror("pipe");
        return 1;
    }

    pid_t child = fork();
    if (child < 0) {
        int saved = errno;
        (void)close(p[0]);
        (void)close(p[1]);
        errno = saved;
        perror("fork");
        return 1;
    }

    if (child == 0) {
        int rc;
        (void)close(p[1]);
        rc = child_read_to_eof(p[0]);
        (void)close(p[0]);
        _exit(rc);
    }

    (void)close(p[0]);
    if (write_all(p[1], payload, sizeof payload) != 0) {
        int saved = errno;
        (void)close(p[1]);
        (void)waitpid(child, NULL, 0);
        errno = saved;
        perror("write");
        return 1;
    }

    if (close(p[1]) < 0) {
        int saved = errno;
        (void)waitpid(child, NULL, 0);
        errno = saved;
        perror("close writer");
        return 1;
    }

    int status;
    pid_t waited;
    do {
        waited = waitpid(child, &status, 0);
    } while (waited < 0 && errno == EINTR);

    if (waited < 0) {
        perror("waitpid");
        return 1;
    }
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        fprintf(stderr, "child did not complete EOF regression cleanly\n");
        return 1;
    }

    puts("fd regression: final writer closed; child observed EOF; child reaped");
    return 0;
}

static int file_mode(const char *path)
{
    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        fprintf(stderr, "open %s: %s\n", path, strerror(errno));
        return 1;
    }

    if (close(fd) < 0) {
        fprintf(stderr, "close %s: %s\n", path, strerror(errno));
        return 1;
    }

    printf("file regression: opened and closed %s\n", path);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "modes: memory bytes fd file PATH\n");
        return 2;
    }

    if (strcmp(argv[1], "memory") == 0 && argc == 2)
        return memory_mode();
    if (strcmp(argv[1], "bytes") == 0 && argc == 2)
        return bytes_mode();
    if (strcmp(argv[1], "fd") == 0 && argc == 2)
        return fd_mode();
    if (strcmp(argv[1], "file") == 0 && argc == 3)
        return file_mode(argv[2]);

    fprintf(stderr, "modes: memory bytes fd file PATH\n");
    return 2;
}
