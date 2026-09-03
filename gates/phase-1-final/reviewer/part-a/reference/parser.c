#define _POSIX_C_SOURCE 200809L
#include "parser.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <limits.h>

enum parser_status sifter_parse_line(const char *line, size_t len,
                                     struct sifter_record *out_rec)
{
    if (len == 0) {
        return PARSE_ERR_SYNTAX;
    }
    if (len > SIFTER_MAX_LINE) {
        return PARSE_ERR_TOOLONG;
    }

    char buf[SIFTER_MAX_LINE + 1];
    memcpy(buf, line, len);
    buf[len] = '\0';

    /* Strip trailing newline / carriage return */
    while (len > 0 && (buf[len - 1] == '\n' || buf[len - 1] == '\r')) {
        buf[--len] = '\0';
    }
    if (len == 0) {
        return PARSE_ERR_SYNTAX;
    }

    char *endptr = NULL;

    /* 1. timestamp_ns: uint64 */
    errno = 0;
    unsigned long long ts = strtoull(buf, &endptr, 10);
    if (errno == ERANGE || endptr == buf || *endptr != ' ') {
        return PARSE_ERR_SYNTAX;
    }

    /* Advance past space */
    while (*endptr == ' ') {
        endptr++;
    }
    char *p2 = endptr;

    /* 2. sensor_id: uint8 */
    errno = 0;
    unsigned long sid = strtoul(p2, &endptr, 10);
    if (errno == ERANGE || endptr == p2 || (*endptr != ' ' && *endptr != '\0') || sid > 255) {
        return PARSE_ERR_RANGE;
    }

    /* Advance past space */
    while (*endptr == ' ') {
        endptr++;
    }
    char *p3 = endptr;

    /* 3. metric_val: int32 */
    errno = 0;
    long long mval = strtoll(p3, &endptr, 10);
    if (errno == ERANGE || endptr == p3 || (*endptr != '\0' && *endptr != ' ' && *endptr != '\n')) {
        return PARSE_ERR_RANGE;
    }
    if (mval < (long long)INT32_MIN || mval > (long long)INT32_MAX) {
        return PARSE_ERR_RANGE;
    }

    if (out_rec != NULL) {
        out_rec->timestamp_ns = (uint64_t)ts;
        out_rec->sensor_id = (uint8_t)sid;
        out_rec->metric_val = (int32_t)mval;
    }

    return PARSE_OK;
}
