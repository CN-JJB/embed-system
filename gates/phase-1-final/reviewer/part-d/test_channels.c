#define _POSIX_C_SOURCE 200809L
#include "reference/pipeline.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <assert.h>
#include <string.h>

static int count_pipe_fds(pid_t pid) {
    char path[64];
    snprintf(path, sizeof(path), "/proc/%d/fd", (int)pid);
    DIR *d = opendir(path);
    if (!d) return -1;
    int pipe_count = 0;
    struct dirent *ent;
    while ((ent = readdir(d)) != NULL) {
        if (ent->d_name[0] == '.') continue;
        char link_target[512];
        char link_path[512];
        snprintf(link_path, sizeof(link_path), "%s/%s", path, ent->d_name);
        ssize_t n = readlink(link_path, link_target, sizeof(link_target) - 1);
        if (n > 0) {
            link_target[n] = '\0';
            if (strncmp(link_target, "pipe:", 5) == 0) {
                pipe_count++;
            }
        }
    }
    closedir(d);
    return pipe_count;
}

int main(void) {
    printf("=== Demonstrating Part D Dual Evidence Channels ===\n");

    /* Channel 1 Demonstration: OS / Process / FD table inspection */
    int p_fd[2];
    assert(pipe(p_fd) == 0);
    printf("[Channel 1 - OS/FD] Created pipe with read_fd=%d, write_fd=%d\n", p_fd[0], p_fd[1]);

    int initial_pipe_fds = count_pipe_fds(getpid());
    assert(initial_pipe_fds >= 2);
    printf("[Channel 1 - OS/FD] Verified %d open pipe descriptors in /proc/self/fd.\n", initial_pipe_fds);

    close(p_fd[1]);
    int post_close_pipe_fds = count_pipe_fds(getpid());
    assert(post_close_pipe_fds == initial_pipe_fds - 1);
    printf("[Channel 1 - OS/FD] Closing write descriptor reduced pipe descriptors to %d (proves EOF eligibility).\n",
           post_close_pipe_fds);
    close(p_fd[0]);

    /* Channel 2 Demonstration: Thread lifecycle coordination & drain */
    printf("[Channel 2 - Concurrency] Testing consumer thread lifecycle join & drain...\n");
    int pipe_test[2];
    assert(pipe(pipe_test) == 0);

    struct queue_item item = { .id = 1, .value = 42 };
    assert(write(pipe_test[1], &item, sizeof(item)) == sizeof(item));
    close(pipe_test[1]);

    struct telemetry_pipeline pipeline;
    assert(pipeline_start(&pipeline, pipe_test[0]) == 0);
    assert(pipeline_stop(&pipeline) == 0);

    /* Verified that joined consumer drained exactly 1 record */
    printf("[Channel 2 - Concurrency] Joined consumer processed %lu items (sum=%ld).\n",
           (unsigned long)pipeline.processed_count, (long)pipeline.accumulated_sum);
    assert(pipeline.processed_count == 1);
    assert(pipeline.accumulated_sum == 42);

    pipeline_destroy(&pipeline);
    close(pipe_test[0]);

    printf(">>> SUCCESS: Both diagnostic channels verified experimentally <<<\n");
    return 0;
}
