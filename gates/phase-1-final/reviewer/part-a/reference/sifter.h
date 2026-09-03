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

typedef int (*sifter_record_cb)(const struct sifter_record *rec, void *ctx);

/*
 * Process stream from in_fd, filtering records by threshold and writing
 * accepted records to out_fd. Updates stats if non-NULL.
 * Returns 0 on success, or non-zero error code.
 */
int sifter_process_stream(int in_fd, int out_fd, int32_t filter_threshold,
                          struct sifter_stats *stats);

#endif /* SIFTER_H */
