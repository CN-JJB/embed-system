
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

static int wait_child(pid_t pid, const char *name)
{
    int status;
    while (waitpid(pid, &status, 0) < 0) {
        if (errno == EINTR) continue;
        perror("waitpid");
        return -1;
    }
    if (WIFEXITED(status)) {
        printf("%s_exit=%d\n", name, WEXITSTATUS(status));
        return WEXITSTATUS(status);
    }
    if (WIFSIGNALED(status)) {
        printf("%s_signal=%d\n", name, WTERMSIG(status));
        return 128 + WTERMSIG(status);
    }
    return -1;
}

int main(void)
{
    int p[2];
    pid_t consumer, producer;
    int rc1, rc2;

    if (pipe(p) != 0) { perror("pipe"); return 1; }

    consumer = fork();
    if (consumer < 0) {
        perror("fork consumer");
        close(p[0]); close(p[1]);
        return 1;
    }
    if (consumer == 0) {
        if (dup2(p[0], STDIN_FILENO) < 0) _exit(120);
        if (p[0] != STDIN_FILENO) close(p[0]);
        if (p[1] != STDIN_FILENO) close(p[1]);
        execl("./consumer", "consumer", (char *)NULL);
        _exit(127);
    }

    producer = fork();
    if (producer < 0) {
        perror("fork producer");
        close(p[0]);
        close(p[1]); /* gives existing consumer EOF */
        (void)wait_child(consumer, "consumer");
        return 1;
    }
    if (producer == 0) {
        if (dup2(p[1], STDOUT_FILENO) < 0) _exit(121);
        if (p[0] != STDOUT_FILENO) close(p[0]);
        if (p[1] != STDOUT_FILENO) close(p[1]);
        execl("./producer", "producer", (char *)NULL);
        _exit(127);
    }

    close(p[0]);
    close(p[1]);

    rc1 = wait_child(producer, "producer");
    rc2 = wait_child(consumer, "consumer");
    return (rc1 == 0 && rc2 == 0) ? 0 : 1;
}
