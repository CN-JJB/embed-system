#define _POSIX_C_SOURCE 200809L
#include "reference/app_lifecycle.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <string.h>
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

    /* 4. Processing Failure After BOTH Owned Descriptors Are Open */
    printf("--- 4. Testing Processing Failure After Both Owned FDs Are Open ---\n");
    /* Opening a directory as input succeeds with open(O_RDONLY), but read() fails with EISDIR */
    const char *dir_input_path = "/tmp";
    const char *proc_fail_out_path = "/tmp/sifter_test_proc_fail.out";
    struct sifter_io_config cfg_proc_fail = {
        .input_path = dir_input_path,
        .output_path = proc_fail_out_path,
        .filter_threshold = 0
    };
    int res_proc_fail = sifter_run_application_lifecycle(&cfg_proc_fail, &stats);
    assert(res_proc_fail != 0);
    unlink(proc_fail_out_path);

    int post_proc_fail_fds = count_open_fds();
    printf("[fd-audit] Post-processing-failure active FDs: %d (baseline was %d)\n", post_proc_fail_fds, base_fds);
    if (post_proc_fail_fds != base_fds) {
        fprintf(stderr, "FAIL: Descriptors retained after stream processing error! Baseline=%d, Post=%d\n",
                base_fds, post_proc_fail_fds);
        return 1;
    }
    printf("PASS: Both owned input and output descriptors cleanly reclaimed after stream failure.\n");

    /* 5. Actual Borrowed STDIN / STDOUT Helper Path Execution */
    printf("--- 5. Testing Actual Borrowed STDIN / STDOUT Helper Path ---\n");
    int saved_stdin = dup(STDIN_FILENO);
    int saved_stdout = dup(STDOUT_FILENO);
    assert(saved_stdin >= 0 && saved_stdout >= 0);

    /* Redirect STDIN to valid fixture file */
    int in_fix_fd = open(fixtures_path, O_RDONLY);
    assert(in_fix_fd >= 0);
    assert(dup2(in_fix_fd, STDIN_FILENO) >= 0);
    close(in_fix_fd);

    /* Redirect STDOUT to /dev/null */
    int devnull_fd = open("/dev/null", O_WRONLY);
    assert(devnull_fd >= 0);
    assert(dup2(devnull_fd, STDOUT_FILENO) >= 0);
    close(devnull_fd);

    struct sifter_io_config cfg_borrowed = {
        .input_path = "-",
        .output_path = "-",
        .filter_threshold = 0
    };
    int res_borrowed = sifter_run_application_lifecycle(&cfg_borrowed, &stats);
    assert(res_borrowed == 0);

    /* Verify FD 0 and FD 1 are still open and functional */
    assert(fcntl(STDIN_FILENO, F_GETFD) != -1);
    assert(fcntl(STDOUT_FILENO, F_GETFD) != -1);

    /* Restore original STDIN and STDOUT */
    assert(dup2(saved_stdin, STDIN_FILENO) >= 0);
    assert(dup2(saved_stdout, STDOUT_FILENO) >= 0);
    close(saved_stdin);
    close(saved_stdout);

    int post_borrowed_fds = count_open_fds();
    printf("[fd-audit] Post-borrowed active FDs: %d (baseline was %d)\n", post_borrowed_fds, base_fds);
    assert(post_borrowed_fds == base_fds);
    printf("PASS: Borrowed stdin/stdout ('-') path invoked and verified intact.\n");

    printf(">>> SUCCESS: In-process application descriptor lifecycle audit passed cleanly <<<\n");
    return 0;
}
