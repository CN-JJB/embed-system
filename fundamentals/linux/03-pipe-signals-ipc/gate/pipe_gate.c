#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

static int pipefd[2] = {-1, -1};
static char *scratch;
static volatile sig_atomic_t stop_requested;

/* SEEDED FAULT: the handler performs application cleanup and stdio. */
static void on_signal(int signo)
{
    stop_requested = 1;
    printf("handler: stopping on signal %d\n", signo);
    free(scratch);
    scratch = NULL;
    if (pipefd[0] >= 0) (void)close(pipefd[0]);
    if (pipefd[1] >= 0) (void)close(pipefd[1]);
}

static int install_handlers(void)
{
    struct sigaction sa;
    sa.sa_handler = on_signal;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    return sigaction(SIGTERM, &sa, NULL) == 0 && sigaction(SIGINT, &sa, NULL) == 0 ? 0 : -1;
}

int main(void)
{
    pid_t consumer;
    pid_t producer;
    int status;

    scratch = malloc(64U);
    if (scratch == NULL || install_handlers() != 0 || pipe(pipefd) != 0) {
        perror("setup");
        free(scratch);
        return 2;
    }

    consumer = fork();
    if (consumer < 0) { perror("fork consumer"); return 2; }
    if (consumer == 0) {
        int retained_write = pipefd[1];
        if (retained_write == STDIN_FILENO) {
            retained_write = dup(pipefd[1]);
            if (retained_write < 0) _exit(126);
        }
        if (dup2(pipefd[0], STDIN_FILENO) < 0) _exit(126);
        if (pipefd[0] != STDIN_FILENO) (void)close(pipefd[0]);
        /* SEEDED FAULT: retained_write deliberately survives exec. */
        (void)retained_write;
        execl("./consumer", "consumer", (char *)NULL);
        _exit(127);
    }

    producer = fork();
    if (producer < 0) {
        perror("fork producer");
        /* SEEDED FAULT: existing child is not reaped on this partial-success path. */
        return 2;
    }
    if (producer == 0) {
        int retained_write = pipefd[1];
        if (retained_write == STDOUT_FILENO) {
            retained_write = dup(pipefd[1]);
            if (retained_write < 0) _exit(126);
        }
        if (dup2(pipefd[1], STDOUT_FILENO) < 0) _exit(126);
        if (pipefd[0] != STDOUT_FILENO) (void)close(pipefd[0]);
        /* SEEDED FAULT: an extra write descriptor is retained across exec. */
        (void)retained_write;
        execl("./producer", "producer", (char *)NULL);
        _exit(127);
    }

    (void)close(pipefd[0]);
    pipefd[0] = -1;
    /* SEEDED FAULT: parent keeps its write end, so consumer cannot observe EOF. */

    printf("supervisor=%ld producer=%ld consumer=%ld\n",
           (long)getpid(), (long)producer, (long)consumer);
    printf("checkpoint: inspect /proc/<pid>/fd before fixing; SIGTERM also audits handler design\n");
    fflush(stdout);

    /* SEEDED FAULT: waits only producer first, then blocks on consumer; no coherent shutdown/reap path. */
    if (waitpid(producer, &status, 0) < 0) perror("wait producer");
    if (waitpid(consumer, &status, 0) < 0 && errno != EINTR) perror("wait consumer");

    if (!stop_requested) free(scratch);
    return 0;
}
