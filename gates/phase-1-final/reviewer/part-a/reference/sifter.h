#ifndef SIFTER_H
#define SIFTER_H

#include <stdint.h>
#include <stddef.h>

struct sifter_record {
    uint64_t timestamp_ns;
    uint8_t  sensor_id;
    int32_t  metric_val;
};

struct sifter_stats {
    size_t total_lines;
    size_t valid_records;
    size_t filtered_records;
    size_t error_records;
};

/* Callback signature accepting record and caller-provided context pointer */
typedef int (*sifter_record_cb)(const struct sifter_record *rec, void *ctx);

/*
 * Process stream from in_fd, dispatching each valid record to caller-supplied callback cb.
 * Updates stats if non-NULL.
 * Returns 0 on success, or non-zero error code.
 */
int sifter_process_stream(int in_fd, sifter_record_cb cb, void *ctx,
                          struct sifter_stats *stats);

/* Default standard filter context and callback implementation */
struct sifter_filter_ctx {
    int out_fd;
    int32_t threshold;
    size_t emitted_records;
};

int sifter_filter_cb(const struct sifter_record *rec, void *ctx);

#endif /* SIFTER_H */
