#include "parser.h"
#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX_LINE 128u

static int parse_u64_token(const char *s, uint64_t max, uint64_t *out) {
    char *end = 0;
    unsigned long long v;

    if (*s == '-' || *s == '+' || *s == '\0')
        return -1;

    errno = 0;
    v = strtoull(s, &end, 0);
    if (errno == ERANGE || end == s || *end != '\0' || v > max)
        return -1;

    *out = (uint64_t)v;
    return 0;
}

static int parse_i32_token(const char *s, int32_t *out) {
    char *end = 0;
    long long v;

    if (*s == '\0')
        return -1;

    errno = 0;
    v = strtoll(s, &end, 0);
    if (errno == ERANGE || end == s || *end != '\0' ||
        v < INT32_MIN || v > INT32_MAX)
        return -1;

    *out = (int32_t)v;
    return 0;
}

static int parse_line(char *line, struct telemetry_record *r) {
    char *tok[5] = {0};
    size_t n = 0;
    char *save = 0;
    char *p;
    uint64_t v;

    for (p = strtok_r(line, " \t\r\n", &save);
         p != 0;
         p = strtok_r(0, " \t\r\n", &save)) {
        if (n >= 5)
            return -1;
        tok[n++] = p;
    }

    if (n != 4)
        return -1;

    r->version = TELEMETRY_VERSION;

    if (parse_u64_token(tok[0], UINT8_MAX, &v) != 0)
        return -1;
    r->kind = (uint8_t)v;

    if (parse_u64_token(tok[1], UINT16_MAX, &v) != 0)
        return -1;
    r->flags = (uint16_t)v;

    if (parse_i32_token(tok[2], &r->value) != 0)
        return -1;

    if (parse_u64_token(tok[3], UINT32_MAX, &v) != 0)
        return -1;
    r->sequence = (uint32_t)v;

    return 0;
}

int parse_text_fd(int fd, record_sink_fn sink, void *ctx,
                  volatile sig_atomic_t *stop_requested) {
    char line[MAX_LINE + 1];
    size_t used = 0;
    int discarding = 0;

    if (fd < 0 || sink == 0)
        return PARSER_INVALID;

    for (;;) {
        char ch;
        ssize_t n;

        /*
         * A stop signal may arrive after one read has completed but before
         * the next read begins. Check the flag before blocking again so
         * shutdown does not depend on the signal interrupting read(2).
         */
        if (stop_requested && *stop_requested)
            return PARSER_STOPPED;

        n = read(fd, &ch, 1);
        if (n == 0) {
            if (discarding)
                return PARSER_INVALID;
            if (used > 0) {
                struct telemetry_record r;

                line[used] = '\0';
                if (parse_line(line, &r) != 0)
                    return PARSER_INVALID;
                if (sink(&r, ctx) != 0)
                    return PARSER_SINK;
            }
            return PARSER_OK;
        }

        if (n < 0) {
            if (errno == EINTR) {
                if (stop_requested && *stop_requested)
                    return PARSER_STOPPED;
                continue;
            }
            return PARSER_IO;
        }

        if (discarding) {
            if (ch == '\n')
                return PARSER_INVALID;
            continue;
        }

        if (ch == '\n') {
            struct telemetry_record r;

            if (used == 0)
                continue;

            line[used] = '\0';
            if (parse_line(line, &r) != 0)
                return PARSER_INVALID;
            if (sink(&r, ctx) != 0)
                return PARSER_SINK;
            used = 0;
        } else if (used >= MAX_LINE) {
            discarding = 1;
        } else {
            line[used++] = ch;
        }
    }
}
