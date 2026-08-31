#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <sys/wait.h>
#include <unistd.h>

static volatile sig_atomic_t stop_requested;

static void on_signal(int signo)
{
    (void)signo;
    stop_requested = 1;
}

static int install_handlers(void)
{
    struct sigaction sa;
    sa.sa_handler = on_signal;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    return sigaction(SIGTERM, &sa, NULL) == 0 &&
           sigaction(SIGINT, &sa, NULL) == 0 ? 0 : -1;
}

static void close_if_open(int *fd)
{
    if (*fd >= 0) {
        (void)close(*fd);
        *fd = -1;
    }
}

static void request_child_stop(pid_t pid)
{
    if (pid > 0) (void)kill(pid, SIGTERM);
}

static int reap_child(pid_t pid, const char *name)
{
    int status;
    pid_t r;

    if (pid <= 0) return 0;
    if (stop_requested) request_child_stop(pid);

    for (;;) {
        r = waitpid(pid, &status, 0);
        if (r >= 0) break;
        if (errno == EINTR) {
            if (stop_requested) request_child_stop(pid);
            continue;
        }
        perror("waitpid");
        return -1;
    }

    if (WIFEXITED(status)) {
        printf("%s: exit=%d\n", name, WEXITSTATUS(status));
        return WEXITSTATUS(status) == 0 ? 0 : -1;
    }
    if (WIFSIGNALED(status)) {
        printf("%s: signal=%d\n", name, WTERMSIG(status));
        return stop_requested ? 0 : -1;
    }
    return -1;
}

int main(void)
{
    int pipefd[2] = {-1, -1};
    pid_t consumer = -1;
    pid_t producer = -1;
    int rc = 0;

    if (install_handlers() != 0 || pipe(pipefd) != 0) {
        perror("setup");
        return 2;
    }

    consumer = fork();
    if (consumer < 0) {
        perror("fork consumer");
        close_if_open(&pipefd[0]);
        close_if_open(&pipefd[1]);
        return 2;
    }
    if (consumer == 0) {
        if (dup2(pipefd[0], STDIN_FILENO) < 0) _exit(126);
        if (pipefd[0] != STDIN_FILENO) (void)close(pipefd[0]);
        if (pipefd[1] != STDIN_FILENO) (void)close(pipefd[1]);
        execl("./consumer", "consumer", (char *)NULL);
        _exit(127);
    }

    producer = fork();
    if (producer < 0) {
        perror("fork producer");
        close_if_open(&pipefd[0]);
        close_if_open(&pipefd[1]);
        request_child_stop(consumer);
        (void)reap_child(consumer, "consumer");
        return 2;
    }
    if (producer == 0) {
        if (dup2(pipefd[1], STDOUT_FILENO) < 0) _exit(126);
        if (pipefd[0] != STDOUT_FILENO) (void)close(pipefd[0]);
        if (pipefd[1] != STDOUT_FILENO) (void)close(pipefd[1]);
        execl("./producer", "producer", (char *)NULL);
        _exit(127);
    }

    close_if_open(&pipefd[0]);
    close_if_open(&pipefd[1]);

    if (reap_child(producer, "producer") != 0) rc = 1;
    if (stop_requested) request_child_stop(consumer);
    if (reap_child(consumer, "consumer") != 0) rc = 1;

    puts("supervisor: normal-context cleanup complete");
    return rc;
}
