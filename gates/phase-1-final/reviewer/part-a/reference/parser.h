#ifndef SIFTER_PARSER_H
#define SIFTER_PARSER_H

#include <stddef.h>
#include "sifter.h"

#define SIFTER_MAX_LINE 128

enum parser_status {
    PARSE_OK = 0,
    PARSE_ERR_SYNTAX = 1,
    PARSE_ERR_RANGE = 2,
    PARSE_ERR_TOOLONG = 3
};

/*
 * Parses a single NUL-terminated line into a sifter_record.
 * Validates length <= SIFTER_MAX_LINE, syntax, and numeric boundaries.
 */
enum parser_status sifter_parse_line(const char *line, size_t len,
                                     struct sifter_record *out_rec);

#endif /* SIFTER_PARSER_H */
