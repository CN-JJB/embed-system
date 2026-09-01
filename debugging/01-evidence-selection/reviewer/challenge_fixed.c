#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

struct record {
    uint8_t version;
    uint8_t kind;
    uint16_t flags;
    uint32_t value;
    uint32_t sequence;
};

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
        char *label;
    } h = {0};

    h.label = malloc(8);
    if (h.label == NULL) {
        perror("malloc");
        return 1;
    }

    memcpy(h.label, "reader", 7);
    printf("label=%s\n", h.label);
    free(h.label);
    h.label = NULL;
    puts("memory regression: lifetime covers retained use");
    return 0;
}

static int endian_mode(void)
{
    const unsigned char bytes[4] = {0x78, 0x56, 0x34, 0x12};
    const uint32_t value = get_u32_le(bytes);

    printf("value=0x%08x expected=0x12345678\n", value);
    return value == UINT32_C(0x12345678) ? 0 : 1;
}

static void initialize_record(struct record *r)
{
    r->version = 1;
    r->kind = 2;
    r->flags = UINT16_C(0x1234);
    r->value = UINT32_C(0x12345678);
    r->sequence = UINT32_C(0x90abcdef);
}

static void process_record(const struct record *r)
{
    printf("processing kind=%u sequence=0x%08x\n",
           (unsigned)r->kind, r->sequence);
}

static int state_mode(void)
{
    struct record r;
    const uint32_t expected = UINT32_C(0x90abcdef);

    initialize_record(&r);
    process_record(&r);
    printf("sequence=0x%08x expected=0x%08x\n", r.sequence, expected);
    return r.sequence == expected ? 0 : 1;
}

static int read_exact_file(const char *path, unsigned char *buf, size_t n)
{
    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        fprintf(stderr, "open %s: %s\n", path, strerror(errno));
        return -1;
    }

    size_t off = 0;
    while (off < n) {
        ssize_t nr = read(fd, buf + off, n - off);
        if (nr < 0) {
            if (errno == EINTR)
                continue;
            fprintf(stderr, "read %s: %s\n", path, strerror(errno));
            (void)close(fd);
            return -1;
        }
        if (nr == 0) {
            fprintf(stderr, "short input: %zu/%zu bytes\n", off, n);
            (void)close(fd);
            return -1;
        }
        off += (size_t)nr;
    }

    if (close(fd) < 0) {
        fprintf(stderr, "close %s: %s\n", path, strerror(errno));
        return -1;
    }

    return 0;
}

static int file_mode(const char *path)
{
    unsigned char bytes[12];

    if (read_exact_file(path, bytes, sizeof bytes) != 0)
        return 1;

    printf("file regression: read %zu bytes; value=0x%08x\n",
           sizeof bytes, get_u32_le(bytes + 4));
    return 0;
}

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "modes: memory endian state file PATH\n");
        return 2;
    }

    if (strcmp(argv[1], "memory") == 0 && argc == 2)
        return memory_mode();
    if (strcmp(argv[1], "endian") == 0 && argc == 2)
        return endian_mode();
    if (strcmp(argv[1], "state") == 0 && argc == 2)
        return state_mode();
    if (strcmp(argv[1], "file") == 0 && argc == 3)
        return file_mode(argv[2]);

    fprintf(stderr, "modes: memory endian state file PATH\n");
    return 2;
}
