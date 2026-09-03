#define _POSIX_C_SOURCE 200809L
#include "reference/sifter.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <assert.h>

struct custom_accumulator {
    size_t record_count;
    int64_t total_metric;
    uint8_t max_sensor_id;
};

static int custom_test_cb(const struct sifter_record *rec, void *ctx) {
    struct custom_accumulator *acc = (struct custom_accumulator *)ctx;
    acc->record_count++;
    acc->total_metric += rec->metric_val;
    if (rec->sensor_id > acc->max_sensor_id) {
        acc->max_sensor_id = rec->sensor_id;
    }
    return 0;
}

int main(int argc, char **argv) {
    printf("=== Running Part A Custom Callback & Context Test ===\n");

    const char *fixtures_path = (argc > 1) ? argv[1] : "../../../part-a/fixtures/valid.txt";
    int fd = open(fixtures_path, O_RDONLY);
    if (fd < 0) {
        perror("open valid.txt");
        return 1;
    }

    struct custom_accumulator acc = { 0, 0, 0 };
    struct sifter_stats stats;

    int res = sifter_process_stream(fd, custom_test_cb, &acc, &stats);
    close(fd);

    if (res != 0) {
        fprintf(stderr, "FAIL: sifter_process_stream returned %d\n", res);
        return 1;
    }

    /* In valid.txt, there are 6 records:
       42 + (-15) + 100 + 0 + (-2147483648) + 2147483647 = 126
       sensor_ids: 1, 1, 2, 3, 2, 5 -> max is 5 */
    printf("Accumulated records: %zu, sum: %ld, max_sid: %u\n",
           acc.record_count, (long)acc.total_metric, acc.max_sensor_id);

    assert(acc.record_count == 6);
    assert(acc.total_metric == 126);
    assert(acc.max_sensor_id == 5);
    assert(stats.valid_records == 6);
    assert(stats.error_records == 0);

    printf(">>> SUCCESS: Custom caller callback and void *ctx verified <<<\n");
    return 0;
}
