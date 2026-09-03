#define _POSIX_C_SOURCE 200809L
#include "../../part-d/src/pipeline.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <errno.h>

static void timeout_handler(int sig) {
    (void)sig;
    const char msg[] = "\n>>> TIMEOUT: Partial FD harness exceeded safety watchdog timer! <<<\n";
    write(STDERR_FILENO, msg, sizeof(msg) - 1);
    _exit(2);
}

int main(void) {
    signal(SIGALRM, timeout_handler);
    alarm(3);

    int p_fd[2];
    if (pipe(p_fd) != 0) return 1;

    pid_t pid = fork();
    if (pid < 0) return 1;

    if (pid == 0) {
        int in_fd = p_fd[0];

        /* PARTIAL FIX: Process/FD fault is fixed (close inherited write descriptor) */
        close(p_fd[1]);

        struct telemetry_pipeline pipeline;
        if (pipeline_start(&pipeline, in_fd) != 0) _exit(1);

        /* Concurrency defect remains: pipeline_stop omits consumer thread join */
        pipeline_stop(&pipeline);

        if (pipeline.processed_count != 50) {
            /* Fails deterministically because consumer thread was not joined to complete drain */
            pipeline_destroy(&pipeline);
            close(in_fd);
            _exit(1);
        }

        pipeline_destroy(&pipeline);
        close(in_fd);
        _exit(0);
    }

    close(p_fd[0]);
    for (uint64_t i = 1; i <= 50; i++) {
        struct queue_item item = { .id = i, .value = (int32_t)(i * 10) };
        if (write(p_fd[1], &item, sizeof(item)) != sizeof(item)) break;
    }
    close(p_fd[1]);

    int status = 0;
    if (waitpid(pid, &status, 0) < 0) return 1;
    if (WIFEXITED(status)) {
        alarm(0);
        return WEXITSTATUS(status);
    }
    alarm(0);
    return 1;
}
