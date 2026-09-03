#define _POSIX_C_SOURCE 200809L
#include "reference/sifter.h"
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
    printf("=== Running Part A In-Process File Descriptor Lifecycle Audit ===\n");

    const char *fixtures_path = (argc > 1) ? argv[1] : "../../../part-a/fixtures/valid.txt";

    int base_fds = count_open_fds();
    printf("[fd-audit] Baseline active descriptors in /proc/self/fd: %d\n", base_fds);

    /* 1. In-process owned descriptor lifecycle */
    int in_fd = open(fixtures_path, O_RDONLY | O_CLOEXEC);
    int out_fd = open("/tmp/sifter_test_lifecycle.out", O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    assert(in_fd >= 0 && out_fd >= 0);

    int active_fds = count_open_fds();
    printf("[fd-audit] Descriptors while files are open: %d (expected %d)\n", active_fds, base_fds + 2);
    assert(active_fds == base_fds + 2);

    struct sifter_filter_ctx fctx = { .out_fd = out_fd, .threshold = 0, .emitted_records = 0 };
    struct sifter_stats stats;
    int res = sifter_process_stream(in_fd, sifter_filter_cb, &fctx, &stats);
    assert(res == 0);

    close(in_fd);
    close(out_fd);
    unlink("/tmp/sifter_test_lifecycle.out");

    int post_close_fds = count_open_fds();
    printf("[fd-audit] Descriptors after explicit close: %d (baseline was %d)\n", post_close_fds, base_fds);
    if (post_close_fds != base_fds) {
        fprintf(stderr, "FAIL: Descriptors retained! Baseline=%d, Post=%d\n", base_fds, post_close_fds);
        return 1;
    }

    /* 2. Borrowed descriptor preservation: verify STDIN and STDOUT remain open */
    assert(fcntl(STDIN_FILENO, F_GETFD) != -1);
    assert(fcntl(STDOUT_FILENO, F_GETFD) != -1);
    printf("[fd-audit] Borrowed descriptors (0 and 1) verified active and preserved.\n");

    /* 3. Error path lifecycle: verify descriptor count remains unchanged on failure */
    int invalid_fd = -1;
    int err_res = sifter_process_stream(invalid_fd, sifter_filter_cb, &fctx, &stats);
    assert(err_res != 0);
    int post_err_fds = count_open_fds();
    assert(post_err_fds == base_fds);
    printf("[fd-audit] Error path verified: zero descriptors leaked on stream failure.\n");

    printf(">>> SUCCESS: In-process descriptor lifecycle audit passed cleanly <<<\n");
    return 0;
}
