#define _POSIX_C_SOURCE 200809L
#include "reference/app_lifecycle.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <assert.h>

static int count_open_fds(void) {
    DIR *d = opendir("/proc/self/fd");
    if (!d) {
        return -1;
    }
    int count = 0;
    struct dirent *ent;
    while ((ent = readdir(d)) != NULL) {
        if (ent->d_name[0] != '.') {
            count++;
        }
    }
    closedir(d);
    return count;
}

int main(int argc, char **argv) {
    printf("=== Running Part A Application FD Ownership & Lifecycle Audit ===\n");

    const char *fixtures_path = (argc > 1) ? argv[1] : "../../../part-a/fixtures/valid.txt";

    int base_fds = count_open_fds();
    printf("[fd-audit] Baseline active descriptors in /proc/self/fd: %d\n", base_fds);

    /* 1. Owned Input + Owned Output Success Path */
    printf("--- 1. Testing Owned Input + Owned Output Success Path ---\n");
    const char *out_path = "/tmp/sifter_test_lifecycle.out";
    struct sifter_io_config cfg_success = {
        .input_path = fixtures_path,
        .output_path = out_path,
        .filter_threshold = 0
    };
    struct sifter_stats stats;
    int res_succ = sifter_run_application_lifecycle(&cfg_success, &stats);
    assert(res_succ == 0);
    unlink(out_path);

    int post_succ_fds = count_open_fds();
    printf("[fd-audit] Post-success active FDs: %d (baseline was %d)\n", post_succ_fds, base_fds);
    if (post_succ_fds != base_fds) {
        fprintf(stderr, "FAIL: Descriptors retained after success path! Baseline=%d, Post=%d\n",
                base_fds, post_succ_fds);
        return 1;
    }
    printf("PASS: Success path cleanly closed all owned input and output descriptors.\n");

    /* 2. Output-Open Failure After Input-Open (Must not leak input FD) */
    printf("--- 2. Testing Output-Open Failure After Input-Open ---\n");
    struct sifter_io_config cfg_out_fail = {
        .input_path = fixtures_path,
        .output_path = "/nonexistent_dir_12345/should_fail.out",
        .filter_threshold = 0
    };
    int res_out_fail = sifter_run_application_lifecycle(&cfg_out_fail, &stats);
    assert(res_out_fail != 0);

    int post_out_fail_fds = count_open_fds();
    printf("[fd-audit] Post-output-failure active FDs: %d (baseline was %d)\n", post_out_fail_fds, base_fds);
    if (post_out_fail_fds != base_fds) {
        fprintf(stderr, "FAIL: Input descriptor leaked when output open failed! Baseline=%d, Post=%d\n",
                base_fds, post_out_fail_fds);
        return 1;
    }
    printf("PASS: Input descriptor cleanly reclaimed when output open fails.\n");

    /* 3. Input-Open Failure (Non-existent input path) */
    printf("--- 3. Testing Input-Open Failure Path ---\n");
    struct sifter_io_config cfg_in_fail = {
        .input_path = "/nonexistent_input_12345.txt",
        .output_path = out_path,
        .filter_threshold = 0
    };
    int res_in_fail = sifter_run_application_lifecycle(&cfg_in_fail, &stats);
    assert(res_in_fail != 0);

    int post_in_fail_fds = count_open_fds();
    assert(post_in_fail_fds == base_fds);
    printf("PASS: Zero descriptors leaked when input open fails.\n");

    /* 4. Processing / Parsing with Malformed Input Stream */
    printf("--- 4. Testing Malformed Input Processing Lifecycle ---\n");
    const char *invalid_fixtures_path = "../../../part-a/fixtures/invalid.txt";
    struct sifter_io_config cfg_invalid = {
        .input_path = invalid_fixtures_path,
        .output_path = out_path,
        .filter_threshold = 0
    };
    sifter_run_application_lifecycle(&cfg_invalid, &stats);
    unlink(out_path);

    int post_invalid_fds = count_open_fds();
    assert(post_invalid_fds == base_fds);
    printf("PASS: Descriptors cleanly reclaimed across malformed data streams.\n");

    /* 5. Borrowed Descriptors Preservation (stdin / stdout) */
    printf("--- 5. Testing Borrowed STDIN / STDOUT Preservation ---\n");
    assert(fcntl(STDIN_FILENO, F_GETFD) != -1);
    assert(fcntl(STDOUT_FILENO, F_GETFD) != -1);
    printf("PASS: Borrowed descriptors (0 and 1) verified active and preserved.\n");

    printf(">>> SUCCESS: In-process application descriptor lifecycle audit passed cleanly <<<\n");
    return 0;
}
