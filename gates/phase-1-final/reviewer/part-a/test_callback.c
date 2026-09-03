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

struct fail_test_ctx {
    size_t invocations;
    size_t fail_after;
    int error_sentinel;
};

static int custom_failing_cb(const struct sifter_record *rec, void *ctx) {
    (void)rec;
    struct fail_test_ctx *fctx = (struct fail_test_ctx *)ctx;
    fctx->invocations++;
    if (fctx->invocations >= fctx->fail_after) {
        return fctx->error_sentinel;
    }
    return 0;
}

int main(int argc, char **argv) {
    printf("=== Running Part A Custom Callback & Context Test ===\n");

    const char *fixtures_path = (argc > 1) ? argv[1] : "../../../part-a/fixtures/valid.txt";

    /* 1. Test Successful Callback Execution & State Accumulation */
    printf("--- 1. Testing Successful Callback & Context Accumulation ---\n");
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

    assert(acc.record_count == 6);
    assert(acc.total_metric == 126);
    assert(acc.max_sensor_id == 5);
    assert(stats.valid_records == 6);
    assert(stats.error_records == 0);
    printf("PASS: All 6 records accumulated successfully (sum=%ld, max_sid=%u).\n",
           (long)acc.total_metric, acc.max_sensor_id);

    /* 2. Test Callback Failure Propagation & Early Termination */
    printf("--- 2. Testing Callback Failure Propagation & Termination ---\n");
    int fd2 = open(fixtures_path, O_RDONLY);
    if (fd2 < 0) {
        perror("open valid.txt (2)");
        return 1;
    }

    struct fail_test_ctx fctx = {
        .invocations = 0,
        .fail_after = 2,
        .error_sentinel = -42
    };
    struct sifter_stats stats2;

    int fail_res = sifter_process_stream(fd2, custom_failing_cb, &fctx, &stats2);
    close(fd2);

    if (fail_res != -42) {
        fprintf(stderr, "FAIL: Expected callback failure sentinel -42, got %d\n", fail_res);
        return 1;
    }

    if (fctx.invocations != 2) {
        fprintf(stderr, "FAIL: Expected exactly 2 callback invocations before termination, got %zu\n",
                fctx.invocations);
        return 1;
    }

    printf("PASS: Callback failure propagated (-42), and delivery halted immediately at record %zu.\n",
           fctx.invocations);

    printf(">>> SUCCESS: Custom caller callback, context lifetime, and failure propagation verified <<<\n");
    return 0;
}
