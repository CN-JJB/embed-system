#define _POSIX_C_SOURCE 200809L
#include "reference/pipeline.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <errno.h>

static void timeout_handler(int sig) {
    (void)sig;
    const char msg[] = "\n>>> TIMEOUT: Partial Concurrency harness exceeded safety watchdog timer! <<<\n";
    write(STDERR_FILENO, msg, sizeof(msg) - 1);
    _exit(2);
}

int main(void) {
    signal(SIGALRM, timeout_handler);
    alarm(3);

    int pipe_fds[2];
    if (pipe(pipe_fds) != 0) return 1;

    pid_t pid = fork();
    if (pid < 0) return 1;

    if (pid == 0) {
        int in_fd = pipe_fds[0];

        /* Process/FD defect remains: Child omits close(pipe_fds[1]) */

        struct telemetry_pipeline pipeline;
        if (pipeline_start(&pipeline, in_fd) != 0) _exit(1);

        /* Concurrency fixed: pipeline_stop coordinates and joins both threads */
        pipeline_stop(&pipeline);

        uint64_t count = 0;
        int64_t sum = 0;
        pipeline_get_stats(&pipeline, &count, &sum);
        bool complete = pipeline_is_completed(&pipeline);

        if (!complete || count != 50) {
            pipeline_destroy(&pipeline);
            close(in_fd);
            _exit(1);
        }

        pipeline_destroy(&pipeline);
        close(in_fd);
        _exit(0);
    }

    close(pipe_fds[0]);
    for (uint64_t i = 1; i <= 50; i++) {
        struct queue_item item = { .id = i, .value = (int32_t)(i * 10) };
        if (write(pipe_fds[1], &item, sizeof(item)) != sizeof(item)) break;
    }
    close(pipe_fds[1]);

    int status = 0;
    if (waitpid(pid, &status, 0) < 0) return 1;
    if (WIFEXITED(status)) {
        alarm(0);
        return WEXITSTATUS(status);
    }
    alarm(0);
    return 1;
}
