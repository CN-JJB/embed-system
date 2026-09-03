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
    alarm(3); /* 3-second watchdog timer against indefinite stalls */

    printf("=== Starting Part D Telemetry Streaming Service ===\n");

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
         * BUGGY PROCESS / FD LIFECYCLE:
         * Child inherits p_fd[1] (write descriptor) but fails to close it!
         * Because the child retains an open write end to its own input pipe,
         * read() on p_fd[0] never receives EOF even after parent closes its write end.
         */
        int in_fd = p_fd[0];
        /* close(p_fd[1]); <-- BUG: Omitted! Leaked inherited write descriptor */

        struct telemetry_pipeline pipeline;
        if (pipeline_start(&pipeline, in_fd) != 0) {
            fprintf(stderr, "[child] Failed to start pipeline\n");
            _exit(1);
        }

        /* Wait for pipeline shutdown and join */
        pipeline_stop(&pipeline);
        close(in_fd);
        printf("[child] Clean shutdown complete. Processed=%lu, Sum=%ld\n",
               (unsigned long)pipeline.processed_count, (long)pipeline.accumulated_sum);
        _exit(0);
    }

    /*
     * PARENT (Supervisor)
     */
    close(p_fd[0]); /* Parent does not read from pipe */

    printf("[parent] Streaming 50 telemetry items to worker daemon...\n");
    for (uint64_t i = 1; i <= 50; i++) {
        struct queue_item item = { .id = i, .value = (int32_t)(i * 10) };
        if (write(p_fd[1], &item, sizeof(item)) != sizeof(item)) {
            perror("write");
            break;
        }
    }

    printf("[parent] Completed transmission. Closing write pipe...\n");
    close(p_fd[1]);

    printf("[parent] Waiting for worker daemon to finish and exit...\n");
    int status = 0;
    if (waitpid(pid, &status, 0) < 0) {
        perror("waitpid");
        return 1;
    }

    if (WIFEXITED(status)) {
        int code = WEXITSTATUS(status);
        printf("[parent] Worker daemon exited with code %d\n", code);
        alarm(0);
        return code;
    }

    if (WIFSIGNALED(status)) {
        fprintf(stderr, "[parent] Worker daemon killed by signal %d\n", WTERMSIG(status));
        return 1;
    }

    alarm(0);
    return 0;
}
