#define _POSIX_C_SOURCE 200809L
#include "reference/parser.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

static void check_parse(const char *name, const char *line, enum parser_status expected,
                        uint64_t exp_ts, uint8_t exp_sid, int32_t exp_val)
{
    struct sifter_record rec;
    memset(&rec, 0, sizeof(rec));
    enum parser_status st = sifter_parse_line(line, strlen(line), &rec);
    if (st != expected) {
        fprintf(stderr, "FAIL [%s]: line='%s' expected status %d, got %d\n", name, line, expected, st);
        exit(1);
    }
    if (st == PARSE_OK) {
        if (rec.timestamp_ns != exp_ts || rec.sensor_id != exp_sid || rec.metric_val != exp_val) {
            fprintf(stderr, "FAIL [%s]: parsed values mismatch: got (%lu, %u, %d) expected (%lu, %u, %d)\n",
                    name, (unsigned long)rec.timestamp_ns, rec.sensor_id, rec.metric_val,
                    (unsigned long)exp_ts, exp_sid, exp_val);
            exit(1);
        }
    }
    printf("PASS [%s]\n", name);
}

int main(void) {
    printf("=== Running Comprehensive Part A Boundary Suite ===\n");

    /* 1. Negative timestamp rejected */
    check_parse("negative_timestamp", "-1 1 2\n", PARSE_ERR_SYNTAX, 0, 0, 0);
    check_parse("negative_timestamp_spaces", "  -500 1 2\n", PARSE_ERR_SYNTAX, 0, 0, 0);

    /* 2. UINT64_MAX accepted */
    check_parse("uint64_max", "18446744073709551615 1 2\n", PARSE_OK, 18446744073709551615ULL, 1, 2);

    /* 3. Timestamp overflow rejected */
    check_parse("uint64_overflow", "18446744073709551616 1 2\n", PARSE_ERR_RANGE, 0, 0, 0);

    /* 4. Sensor ID 0 accepted */
    check_parse("sensor_id_0", "100 0 50\n", PARSE_OK, 100, 0, 50);

    /* 5. Sensor ID 255 accepted */
    check_parse("sensor_id_255", "100 255 50\n", PARSE_OK, 100, 255, 50);

    /* 6. Sensor ID 256 rejected */
    check_parse("sensor_id_256", "100 256 50\n", PARSE_ERR_RANGE, 0, 0, 0);

    /* 7. Sensor ID negative rejected */
    check_parse("sensor_id_negative", "100 -1 50\n", PARSE_ERR_SYNTAX, 0, 0, 0);

    /* 8. INT32_MIN accepted */
    check_parse("int32_min", "100 1 -2147483648\n", PARSE_OK, 100, 1, -2147483648);

    /* 9. INT32_MAX accepted */
    check_parse("int32_max", "100 1 2147483647\n", PARSE_OK, 100, 1, 2147483647);

    /* 10. Metric overflow rejected */
    check_parse("int32_overflow", "100 1 2147483648\n", PARSE_ERR_RANGE, 0, 0, 0);

    /* 11. Metric underflow rejected */
    check_parse("int32_underflow", "100 1 -2147483649\n", PARSE_ERR_RANGE, 0, 0, 0);

    /* 12. Trailing non-whitespace garbage rejected */
    check_parse("trailing_garbage", "1 2 3 trailing\n", PARSE_ERR_SYNTAX, 0, 0, 0);
    check_parse("trailing_garbage_chars", "1 2 3x\n", PARSE_ERR_SYNTAX, 0, 0, 0);

    /* 13. Exact maximum permitted line accepted (128 bytes including newline) */
    char max_line[130];
    memset(max_line, ' ', sizeof(max_line));
    /* Construct 128-byte line: "100 1 42" followed by spaces, ending with \n */
    int prefix_len = sprintf(max_line, "100 1 42");
    max_line[prefix_len] = ' ';
    max_line[127] = '\n';
    max_line[128] = '\0';
    assert(strlen(max_line) == 128);
    check_parse("max_128_bytes_line", max_line, PARSE_OK, 100, 1, 42);

    /* 14. One-byte-over-limit line rejected (129 bytes) */
    char over_line[135];
    memset(over_line, ' ', sizeof(over_line));
    prefix_len = sprintf(over_line, "100 1 42");
    over_line[prefix_len] = ' ';
    over_line[128] = '\n';
    over_line[129] = '\0';
    assert(strlen(over_line) == 129);
    check_parse("over_129_bytes_line", over_line, PARSE_ERR_TOOLONG, 0, 0, 0);

    printf(">>> ALL PART A PARSER & GRAMMAR BOUNDARY TESTS PASSED <<<\n");
    return 0;
}
