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
    const char msg[] = "\n>>> TIMEOUT: Part D streaming pipeline hung during shutdown! <<<\n";
    write(STDERR_FILENO, msg, sizeof(msg) - 1);
    _exit(2);
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;

    signal(SIGALRM, timeout_handler);
    alarm(3);

    int p_fd[2];
    if (pipe(p_fd) != 0) {
        perror("pipe");
        return 1;
    }

    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        close(p_fd[0]);
        close(p_fd[1]);
        return 1;
    }

    if (pid == 0) {
        /*
         * CHILD (Worker Daemon)
         *
         * FIXED: Close inherited write end of the communication pipe.
         */
        int in_fd = p_fd[0];
        close(p_fd[1]);

        struct telemetry_pipeline pipeline;
        if (pipeline_start(&pipeline, in_fd) != 0) {
            fprintf(stderr, "[child] Failed to start pipeline\n");
            _exit(1);
        }

        pipeline_stop(&pipeline);
        close(in_fd);
        _exit(0);
    }

    /*
     * PARENT (Supervisor)
     */
    close(p_fd[0]);

    for (uint64_t i = 1; i <= 50; i++) {
        struct queue_item item = { .id = i, .value = (int32_t)(i * 10) };
        if (write(p_fd[1], &item, sizeof(item)) != sizeof(item)) {
            break;
        }
    }

    close(p_fd[1]);

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
