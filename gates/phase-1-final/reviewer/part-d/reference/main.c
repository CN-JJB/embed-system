#define _POSIX_C_SOURCE 200809L
#include "pipeline.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <errno.h>

static void timeout_handler(int sig) {
    (void)sig;
    const char msg[] = "\n>>> TIMEOUT: Telemetry pipeline exceeded safety watchdog timer! <<<\n";
    write(STDERR_FILENO, msg, sizeof(msg) - 1);
    _exit(2);
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;

    signal(SIGALRM, timeout_handler);
    alarm(3);

    int pipe_fds[2];
    if (pipe(pipe_fds) != 0) {
        perror("pipe");
        return 1;
    }

    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        close(pipe_fds[0]);
        close(pipe_fds[1]);
        return 1;
    }

    if (pid == 0) {
        int in_fd = pipe_fds[0];

        /* Fixed Process/FD: Close inherited write end */
        close(pipe_fds[1]);

        struct telemetry_pipeline pipeline;
        if (pipeline_start(&pipeline, in_fd) != 0) {
            fprintf(stderr, "[child] Failed to start pipeline\n");
            _exit(1);
        }

        pipeline_stop(&pipeline);

        uint64_t count = 0;
        int64_t sum = 0;
        pipeline_get_stats(&pipeline, &count, &sum);
        bool complete = pipeline_is_completed(&pipeline);

        if (!complete || count != 50) {
            fprintf(stderr, "[child] Drain verification failed: complete=%d, processed %lu of 50 items\n",
                    (int)complete, (unsigned long)count);
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
        if (write(pipe_fds[1], &item, sizeof(item)) != sizeof(item)) {
            perror("write");
            break;
        }
    }

    close(pipe_fds[1]);

    int status = 0;
    if (waitpid(pid, &status, 0) < 0) {
        perror("waitpid");
        return 1;
    }

    if (WIFEXITED(status)) {
        alarm(0);
        return WEXITSTATUS(status);
    }

    alarm(0);
    return 1;
}
