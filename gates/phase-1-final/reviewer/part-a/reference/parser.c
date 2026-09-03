#define _POSIX_C_SOURCE 200809L
#include "parser.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <limits.h>
#include <ctype.h>

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

    char *p = buf;
    while (*p == ' ' || *p == '\t') {
        p++;
    }
    if (*p == '\0') {
        return PARSE_ERR_SYNTAX;
    }

    /* 1. timestamp_ns: uint64. Must NOT be negative */
    if (*p == '-' || !isdigit((unsigned char)*p)) {
        return PARSE_ERR_SYNTAX;
    }

    char *endptr = NULL;
    errno = 0;
    unsigned long long ts = strtoull(p, &endptr, 10);
    if (errno == ERANGE) {
        return PARSE_ERR_RANGE;
    }
    if (endptr == p || (*endptr != ' ' && *endptr != '\t')) {
        return PARSE_ERR_SYNTAX;
    }

    /* Advance past delimiter */
    while (*endptr == ' ' || *endptr == '\t') {
        endptr++;
    }
    char *p2 = endptr;

    /* 2. sensor_id: uint8. Must NOT be negative */
    if (*p2 == '-' || !isdigit((unsigned char)*p2)) {
        return PARSE_ERR_SYNTAX;
    }

    errno = 0;
    unsigned long sid = strtoul(p2, &endptr, 10);
    if (errno == ERANGE || sid > 255) {
        return PARSE_ERR_RANGE;
    }
    if (endptr == p2 || (*endptr != ' ' && *endptr != '\t')) {
        return PARSE_ERR_SYNTAX;
    }

    /* Advance past delimiter */
    while (*endptr == ' ' || *endptr == '\t') {
        endptr++;
    }
    char *p3 = endptr;

    /* 3. metric_val: int32 signed */
    if (*p3 == '\0') {
        return PARSE_ERR_SYNTAX;
    }
    if (*p3 != '-' && *p3 != '+' && !isdigit((unsigned char)*p3)) {
        return PARSE_ERR_SYNTAX;
    }

    errno = 0;
    long long mval = strtoll(p3, &endptr, 10);
    if (errno == ERANGE || mval < (long long)INT32_MIN || mval > (long long)INT32_MAX) {
        return PARSE_ERR_RANGE;
    }
    if (endptr == p3) {
        return PARSE_ERR_SYNTAX;
    }

    /* Verify no trailing non-whitespace garbage exists */
    while (*endptr == ' ' || *endptr == '\t') {
        endptr++;
    }
    if (*endptr != '\0') {
        return PARSE_ERR_SYNTAX;
    }

    if (out_rec != NULL) {
        out_rec->timestamp_ns = (uint64_t)ts;
        out_rec->sensor_id = (uint8_t)sid;
        out_rec->metric_val = (int32_t)mval;
    }

    return PARSE_OK;
}
