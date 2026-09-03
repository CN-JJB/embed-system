#define _DEFAULT_SOURCE
#define _POSIX_C_SOURCE 200809L
#include "../../part-d/src/pipeline.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <fcntl.h>
#include <dirent.h>
#include <string.h>
#include <assert.h>

static void timeout_handler(int sig) {
    (void)sig;
    const char msg[] = "\n>>> TIMEOUT: test_channels watchdog triggered! <<<\n";
    write(STDERR_FILENO, msg, sizeof(msg) - 1);
    _exit(2);
}

/* Scans /proc/<pid>/fd for open pipe descriptors and counts matching pipe inodes */
static int scan_target_pipe_fds(pid_t pid, char *out_first_inode, size_t buf_size) {
    char path[128];
    snprintf(path, sizeof(path), "/proc/%d/fd", (int)pid);
    DIR *d = opendir(path);
    if (!d) return -1;

    int pipe_count = 0;
    struct dirent *ent;
    while ((ent = readdir(d)) != NULL) {
        if (ent->d_name[0] == '.') continue;
        char link_path[512];
        char target[512];
        snprintf(link_path, sizeof(link_path), "%s/%s", path, ent->d_name);
        ssize_t n = readlink(link_path, target, sizeof(target) - 1);
        if (n > 0) {
            target[n] = '\0';
            if (strncmp(target, "pipe:", 5) == 0) {
                pipe_count++;
                if (out_first_inode && out_first_inode[0] == '\0') {
                    strncpy(out_first_inode, target, buf_size - 1);
                }
            }
        }
    }
    closedir(d);
    return pipe_count;
}

/* Counts active threads in /proc/<pid>/task */
static int count_process_threads(pid_t pid) {
    char path[128];
    snprintf(path, sizeof(path), "/proc/%d/task", (int)pid);
    DIR *d = opendir(path);
    if (!d) return -1;
    int count = 0;
    struct dirent *ent;
    while ((ent = readdir(d)) != NULL) {
        if (ent->d_name[0] != '.') count++;
    }
    closedir(d);
    return count;
}

int main(void) {
    signal(SIGALRM, timeout_handler);
    alarm(5);

    printf("=== Running Part D Dual Target Evidence Channels Audit ===\n");

    /* =========================================================================
     * Channel 1: OS / Process / File Descriptor Boundary on Stalled Target
     * ========================================================================= */
    printf("--- Channel 1: Observing Live Target Process/FD Stall ---\n");

    int p_fds[2];
    assert(pipe(p_fds) == 0);

    pid_t target_pid = fork();
    assert(target_pid >= 0);

    if (target_pid == 0) {
        /* Target Child reproduces the Process/FD defect:
         * Uses p_fds[0] as stream input, but omits closing inherited p_fds[1] */
        int in_fd = p_fds[0];

        struct telemetry_pipeline pipeline;
        if (pipeline_start(&pipeline, in_fd) != 0) _exit(1);

        /* Will block indefinitely here in read() because write handle is retained */
        pipeline_stop(&pipeline);

        pipeline_destroy(&pipeline);
        close(in_fd);
        _exit(0);
    }

    /* Parent / Auditor: stream 10 items, then close parent write descriptor */
    close(p_fds[0]);
    for (uint64_t i = 1; i <= 10; i++) {
        struct queue_item it = { .id = i, .value = (int32_t)i };
        assert(write(p_fds[1], &it, sizeof(it)) == sizeof(it));
    }
    close(p_fds[1]);

    /* Allow target child to ingest stream and enter read stall */
    usleep(50000);

    /* Empirical Evidence Capture: Inspect /proc/<target_pid>/fd */
    char pipe_inode[128] = {0};
    int pipe_fds_in_target = scan_target_pipe_fds(target_pid, pipe_inode, sizeof(pipe_inode));

    printf("[Channel 1 Evidence] Target PID: %d\n", (int)target_pid);
    printf("[Channel 1 Evidence] Pipe inode: '%s'\n", pipe_inode);
    printf("[Channel 1 Evidence] Open pipe descriptors in target: %d (expected 2: read + write)\n",
           pipe_fds_in_target);

    /* Must find at least 2 open pipe descriptors (the read end AND the leaked write end) */
    assert(pipe_fds_in_target >= 2);
    assert(strncmp(pipe_inode, "pipe:", 5) == 0);

    printf("PASS [Channel 1]: Empirically observed unclosed write pipe descriptor in stalled target.\n");

    /* Clean up stalled child */
    kill(target_pid, SIGKILL);
    waitpid(target_pid, NULL, 0);

    /* =========================================================================
     * Channel 2: Concurrency / Lifecycle Drain State on Partial Target
     * ========================================================================= */
    printf("--- Channel 2: Observing Live Concurrency Lifecycle Defect ---\n");

    int c_pipe[2];
    assert(pipe(c_pipe) == 0);
    close(c_pipe[1]); /* EOF immediately */

    struct telemetry_pipeline test_pipeline;
    assert(pipeline_start(&test_pipeline, c_pipe[0]) == 0);

    int threads_before_stop = count_process_threads(getpid());
    printf("[Channel 2 Evidence] Active process threads before stop: %d (expected >= 3)\n", threads_before_stop);
    assert(threads_before_stop >= 3);

    /* Run buggy pipeline_stop (omits consumer handshake and join) */
    pipeline_stop(&test_pipeline);

    bool is_done = pipeline_is_completed(&test_pipeline);
    int threads_after_stop = count_process_threads(getpid());

    printf("[Channel 2 Evidence] pipeline_is_completed(): %d (expected 0)\n", (int)is_done);
    printf("[Channel 2 Evidence] Active process threads after stop: %d (expected >= 2)\n", threads_after_stop);

    assert(is_done == false);
    assert(threads_after_stop >= 2);

    printf("PASS [Channel 2]: Empirically proved consumer thread unjoined and lifecycle incomplete after stop().\n");

    /* Clean up cleanly */
    pipeline_destroy(&test_pipeline);
    close(c_pipe[0]);

    printf(">>> SUCCESS: Both diagnostic channels experimentally verified against target faults <<<\n");
    alarm(0);
    return 0;
}
