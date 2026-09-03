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

/* Counts descriptors in /proc/<pid>/fd whose symlink matches exact expected pipe identity */
static int count_exact_pipe_descriptors(pid_t pid, const char *expected_symlink) {
    char path[128];
    snprintf(path, sizeof(path), "/proc/%d/fd", (int)pid);
    DIR *d = opendir(path);
    if (!d) return -1;

    int match_count = 0;
    struct dirent *ent;
    while ((ent = readdir(d)) != NULL) {
        if (ent->d_name[0] == '.') continue;
        char link_path[512];
        char target[512];
        snprintf(link_path, sizeof(link_path), "%s/%s", path, ent->d_name);
        ssize_t n = readlink(link_path, target, sizeof(target) - 1);
        if (n > 0) {
            target[n] = '\0';
            if (strcmp(target, expected_symlink) == 0) {
                match_count++;
            }
        }
    }
    closedir(d);
    return match_count;
}

/* Bounded state poll: waits until target process reaches steady-state stall with exact pipe */
static int wait_target_pipe_stall(pid_t pid, const char *expected_symlink, int max_poll_ms) {
    int elapsed_ms = 0;
    while (elapsed_ms < max_poll_ms) {
        char stat_path[64];
        snprintf(stat_path, sizeof(stat_path), "/proc/%d/stat", (int)pid);
        FILE *f = fopen(stat_path, "r");
        if (f) {
            char state = ' ';
            int scanned = fscanf(f, "%*d %*s %c", &state);
            fclose(f);
            if (scanned == 1 && state == 'S') {
                int exact_matches = count_exact_pipe_descriptors(pid, expected_symlink);
                if (exact_matches >= 2) {
                    return 0; /* Target has stalled with exact communication pipe handles open */
                }
            }
        }
        usleep(2000); /* 2ms polling backoff */
        elapsed_ms += 2;
    }
    return -1;
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

    /* Obtain the exact communication pipe identity from parent descriptor */
    char expected_pipe_symlink[256];
    char self_fd_path[64];
    snprintf(self_fd_path, sizeof(self_fd_path), "/proc/self/fd/%d", p_fds[1]);
    ssize_t link_len = readlink(self_fd_path, expected_pipe_symlink, sizeof(expected_pipe_symlink) - 1);
    assert(link_len > 0);
    expected_pipe_symlink[link_len] = '\0';
    assert(strncmp(expected_pipe_symlink, "pipe:", 5) == 0);

    pid_t target_pid = fork();
    assert(target_pid >= 0);

    if (target_pid == 0) {
        /* Target Child reproduces the Process/FD defect:
         * Uses p_fds[0] as stream input, but omits closing inherited p_fds[1] */
        int in_fd = p_fds[0];

        struct telemetry_pipeline pipeline;
        if (pipeline_start(&pipeline, in_fd) != 0) _exit(1);

        /* Blocks indefinitely here in read() because write handle is retained */
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
    close(p_fds[1]); /* Parent writer handle closed */

    /* Bounded State Poll: wait until target enters steady-state stall with exact pipe */
    int poll_res = wait_target_pipe_stall(target_pid, expected_pipe_symlink, 2000);
    assert(poll_res == 0);

    /* Empirical Evidence Capture: Inspect /proc/<target_pid>/fd for EXACT pipe identity */
    int exact_pipe_matches = count_exact_pipe_descriptors(target_pid, expected_pipe_symlink);

    printf("[Channel 1 Observation] Target PID: %d\n", (int)target_pid);
    printf("[Channel 1 Observation] Target Communication Pipe: '%s'\n", expected_pipe_symlink);
    printf("[Channel 1 Observation] Descriptors referencing this exact pipe in target: %d (expected 2: read + write)\n",
           exact_pipe_matches);

    assert(exact_pipe_matches == 2);

    printf("[Channel 1 Interpretation] Target process holds an open write reference to the exact stream pipe, "
           "preventing kernel EOF delivery.\n");
    printf("[Channel 1 Non-Proof] Descriptor table evidence proves open file references; "
           "it does not identify arbitrary userspace thread execution state.\n");
    printf("PASS [Channel 1]: Empirically correlated exact communication pipe descriptor retention in stalled target.\n");

    /* Clean up stalled child */
    kill(target_pid, SIGKILL);
    waitpid(target_pid, NULL, 0);

    /* =========================================================================
     * Channel 2: Concurrency / Lifecycle Drain State on Partial Target
     * ========================================================================= */
    printf("--- Channel 2: Observing Live Concurrency Lifecycle Defect ---\n");

    int c_pipe[2];
    assert(pipe(c_pipe) == 0);

    struct telemetry_pipeline test_pipeline;
    assert(pipeline_start(&test_pipeline, c_pipe[0]) == 0);

    int threads_before_stop = count_process_threads(getpid());
    printf("[Channel 2 Observation] Active process threads before stop: %d (expected >= 3)\n", threads_before_stop);
    assert(threads_before_stop >= 3);

    /* Send 1 packet and close writer so reader sees EOF */
    struct queue_item item = { .id = 1, .value = 100 };
    assert(write(c_pipe[1], &item, sizeof(item)) == sizeof(item));
    close(c_pipe[1]);

    /* Run buggy pipeline_stop (omits consumer handshake and join) */
    pipeline_stop(&test_pipeline);

    bool is_done = pipeline_is_completed(&test_pipeline);
    int threads_after_stop = count_process_threads(getpid());

    printf("[Channel 2 Observation] pipeline_is_completed(): %d (expected 0)\n", (int)is_done);
    printf("[Channel 2 Observation] Active process threads after stop: %d (expected >= 2)\n", threads_after_stop);

    assert(is_done == false);
    assert(threads_after_stop >= 2);

    printf("[Channel 2 Interpretation] Concurrency shutdown coordination omitted consumer thread join, "
           "returning to caller while worker thread remained unjoined.\n");
    printf("[Channel 2 Non-Proof] Observing incomplete item count alone does not prove thread omission; "
           "live thread count and lifecycle state provide empirical proof.\n");
    printf("PASS [Channel 2]: Empirically proved consumer thread unjoined and lifecycle incomplete after stop().\n");

    /* Clean up cleanly */
    pipeline_destroy(&test_pipeline);
    close(c_pipe[0]);

    printf(">>> SUCCESS: Both diagnostic channels experimentally verified against target faults <<<\n");
    alarm(0);
    return 0;
}
