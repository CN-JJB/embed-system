#define _POSIX_C_SOURCE 200809L
#include "reference/parser.h"
#include "reference/sifter.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
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

static int dummy_cb(const struct sifter_record *rec, void *ctx) {
    (void)rec;
    (void)ctx;
    return 0;
}

static void test_stream_framing(const char *name, const char *data, size_t len,
                                size_t exp_valid, size_t exp_errors)
{
    int fds[2];
    if (pipe(fds) != 0) {
        perror("pipe");
        exit(1);
    }

    /* Write test data to pipe */
    size_t written = 0;
    while (written < len) {
        ssize_t n = write(fds[1], data + written, len - written);
        if (n <= 0) break;
        written += (size_t)n;
    }
    close(fds[1]); /* EOF for reader */

    struct sifter_stats stats;
    int res = sifter_process_stream(fds[0], dummy_cb, NULL, &stats);
    close(fds[0]);

    if (res != 0) {
        fprintf(stderr, "FAIL [%s]: sifter_process_stream returned non-zero %d\n", name, res);
        exit(1);
    }

    if (stats.valid_records != exp_valid || stats.error_records != exp_errors) {
        fprintf(stderr, "FAIL [%s]: Stream framing mismatch! Expected valid=%zu errors=%zu, got valid=%zu errors=%zu\n",
                name, exp_valid, exp_errors, stats.valid_records, stats.error_records);
        exit(1);
    }
    printf("PASS [stream: %s] -> valid=%zu, errors=%zu\n", name, stats.valid_records, stats.error_records);
}

int main(void) {
    printf("=== Running Comprehensive Part A Boundary Suite ===\n");

    /* --- Part 1: Parser Grammar & Numeric Boundaries --- */
    printf("--- 1. Parser Grammar & Numeric Tests ---\n");
    check_parse("negative_timestamp", "-1 1 2\n", PARSE_ERR_SYNTAX, 0, 0, 0);
    check_parse("negative_timestamp_spaces", "  -500 1 2\n", PARSE_ERR_SYNTAX, 0, 0, 0);
    check_parse("uint64_max", "18446744073709551615 1 2\n", PARSE_OK, 18446744073709551615ULL, 1, 2);
    check_parse("uint64_overflow", "18446744073709551616 1 2\n", PARSE_ERR_RANGE, 0, 0, 0);
    check_parse("sensor_id_0", "100 0 50\n", PARSE_OK, 100, 0, 50);
    check_parse("sensor_id_255", "100 255 50\n", PARSE_OK, 100, 255, 50);
    check_parse("sensor_id_256", "100 256 50\n", PARSE_ERR_RANGE, 0, 0, 0);
    check_parse("sensor_id_negative", "100 -1 50\n", PARSE_ERR_SYNTAX, 0, 0, 0);
    check_parse("int32_min", "100 1 -2147483648\n", PARSE_OK, 100, 1, -2147483648);
    check_parse("int32_max", "100 1 2147483647\n", PARSE_OK, 100, 1, 2147483647);
    check_parse("int32_overflow", "100 1 2147483648\n", PARSE_ERR_RANGE, 0, 0, 0);
    check_parse("int32_underflow", "100 1 -2147483649\n", PARSE_ERR_RANGE, 0, 0, 0);
    check_parse("trailing_garbage", "1 2 3 trailing\n", PARSE_ERR_SYNTAX, 0, 0, 0);
    check_parse("trailing_garbage_chars", "1 2 3x\n", PARSE_ERR_SYNTAX, 0, 0, 0);

    /* --- Part 2: End-to-End Stream Layer Physical Record Boundaries --- */
    printf("--- 2. End-to-End Stream Layer Physical Record Boundaries ---\n");

    /* Case A: bytes=128 newline=1 -> valid=1, errors=0
     * Construct 127 non-newline bytes ("100 1 42" + padding spaces) + '\n' = 128 bytes total */
    char buf_128_nl[130];
    memset(buf_128_nl, ' ', sizeof(buf_128_nl));
    int prefix = sprintf(buf_128_nl, "100 1 42");
    buf_128_nl[prefix] = ' ';
    buf_128_nl[127] = '\n';
    test_stream_framing("bytes=128 newline=1", buf_128_nl, 128, 1, 0);

    /* Case B: bytes=129 newline=1 -> valid=0, errors=1
     * Construct 128 non-newline bytes + '\n' = 129 bytes total -> MUST BE REJECTED */
    char buf_129_nl[132];
    memset(buf_129_nl, ' ', sizeof(buf_129_nl));
    prefix = sprintf(buf_129_nl, "100 1 42");
    buf_129_nl[prefix] = ' ';
    buf_129_nl[128] = '\n';
    test_stream_framing("bytes=129 newline=1", buf_129_nl, 129, 0, 1);

    /* Case C: bytes=128 newline=0 (EOF) -> valid=1, errors=0
     * Construct 128 non-newline bytes ("100 1 42" + padding spaces) terminated by EOF */
    char buf_128_eof[130];
    memset(buf_128_eof, ' ', sizeof(buf_128_eof));
    prefix = sprintf(buf_128_eof, "100 1 42");
    buf_128_eof[prefix] = ' ';
    test_stream_framing("bytes=128 newline=0", buf_128_eof, 128, 1, 0);

    /* Case D: bytes=129 newline=0 (EOF) -> valid=0, errors=1
     * Construct 129 non-newline bytes terminated by EOF -> MUST BE REJECTED */
    char buf_129_eof[132];
    memset(buf_129_eof, ' ', sizeof(buf_129_eof));
    prefix = sprintf(buf_129_eof, "100 1 42");
    buf_129_eof[prefix] = ' ';
    test_stream_framing("bytes=129 newline=0", buf_129_eof, 129, 0, 1);

    printf(">>> ALL PART A PARSER & STREAM BOUNDARY TESTS PASSED <<<\n");
    return 0;
}
