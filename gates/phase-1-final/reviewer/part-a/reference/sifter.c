#define _POSIX_C_SOURCE 200809L
#include "sifter.h"
#include "parser.h"
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <inttypes.h>

struct emit_ctx {
    int out_fd;
    int32_t threshold;
    struct sifter_stats *stats;
};

static int safe_write_all(int fd, const char *buf, size_t len) {
    size_t total_written = 0;
    while (total_written < len) {
        ssize_t n = write(fd, buf + total_written, len - total_written);
        if (n < 0) {
            if (errno == EINTR) {
                continue;
            }
            return -1;
        }
        if (n == 0) {
            return -1;
        }
        total_written += (size_t)n;
    }
    return 0;
}

static int sifter_default_cb(const struct sifter_record *rec, void *ctx) {
    struct emit_ctx *ec = (struct emit_ctx *)ctx;
    if (ec->stats != NULL) {
        ec->stats->valid_records++;
    }

    if (rec->metric_val >= ec->threshold) {
        if (ec->stats != NULL) {
            ec->stats->filtered_records++;
        }
        char line[SIFTER_MAX_LINE + 1];
        int n = snprintf(line, sizeof(line), "%" PRIu64 " %u %" PRId32 "\n",
                         rec->timestamp_ns, (unsigned)rec->sensor_id, rec->metric_val);
        if (n > 0 && (size_t)n < sizeof(line)) {
            if (safe_write_all(ec->out_fd, line, (size_t)n) != 0) {
                return -1;
            }
        }
    }
    return 0;
}

int sifter_process_stream(int in_fd, int out_fd, int32_t filter_threshold,
                          struct sifter_stats *stats)
{
    if (stats != NULL) {
        memset(stats, 0, sizeof(*stats));
    }

    struct emit_ctx ctx = {
        .out_fd = out_fd,
        .threshold = filter_threshold,
        .stats = stats
    };

    char read_buf[256];
    char line_buf[SIFTER_MAX_LINE + 2];
    size_t line_len = 0;
    int discarding_too_long = 0;

    for (;;) {
        ssize_t nread = read(in_fd, read_buf, sizeof(read_buf));
        if (nread < 0) {
            if (errno == EINTR) {
                continue;
            }
            return -1;
        }
        if (nread == 0) {
            break; /* EOF */
        }

        for (ssize_t i = 0; i < nread; i++) {
            char c = read_buf[i];
            if (c == '\n') {
                if (discarding_too_long) {
                    discarding_too_long = 0;
                    line_len = 0;
                    continue;
                }
                if (line_len > 0) {
                    if (stats != NULL) {
                        stats->total_lines++;
                    }
                    struct sifter_record rec;
                    enum parser_status st = sifter_parse_line(line_buf, line_len, &rec);
                    if (st == PARSE_OK) {
                        if (sifter_default_cb(&rec, &ctx) != 0) {
                            return -1;
                        }
                    } else {
                        if (stats != NULL) {
                            stats->error_records++;
                        }
                    }
                    line_len = 0;
                }
            } else {
                if (discarding_too_long) {
                    continue;
                }
                if (line_len < SIFTER_MAX_LINE) {
                    line_buf[line_len++] = c;
                } else {
                    /* Line exceeds limit; mark discard and record error */
                    discarding_too_long = 1;
                    if (stats != NULL) {
                        stats->total_lines++;
                        stats->error_records++;
                    }
                    line_len = 0;
                }
            }
        }
    }

    /* Process trailing line without newline if present */
    if (line_len > 0 && !discarding_too_long) {
        if (stats != NULL) {
            stats->total_lines++;
        }
        struct sifter_record rec;
        enum parser_status st = sifter_parse_line(line_buf, line_len, &rec);
        if (st == PARSE_OK) {
            if (sifter_default_cb(&rec, &ctx) != 0) {
                return -1;
            }
        } else {
            if (stats != NULL) {
                stats->error_records++;
            }
        }
    }

    return 0;
}
