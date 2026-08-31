#define _POSIX_C_SOURCE 200809L
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/wait.h>
#include <unistd.h>


static int child_state(pid_t pid, char *state)
{
    char path[64];
    snprintf(path, sizeof path, "/proc/%ld/stat", (long)pid);
    FILE *fp = fopen(path, "r");
    if (!fp) return -1;
    long seen_pid;
    char comm[256];
    char st;
    int rc = fscanf(fp, "%ld %255s %c", &seen_pid, comm, &st);
    fclose(fp);
    if (rc != 3) return -1;
    *state = st;
    return 0;
}

static int wait_until_both_zombie(pid_t a, pid_t b)
{
    struct timespec pause = {.tv_sec = 0, .tv_nsec = 10 * 1000 * 1000};
    for (int i = 0; i < 500; ++i) {
        char sa = '?', sb = '?';
        if (child_state(a, &sa) == 0 && child_state(b, &sb) == 0 && sa == 'Z' && sb == 'Z') return 0;
        nanosleep(&pause, NULL);
    }
    return -1;
}

static pid_t spawn_one(const char *path, const char *code)
{
    pid_t pid = fork();
    if (pid == -1) return -1;
    if (pid == 0) {
        char *const argv[] = {(char *)path, (char *)code, NULL};
        execv(path, argv);
        perror("execv");
        return -1; /* BUG: child falls back into caller control path */
    }
    return pid;
}

static void report_status(pid_t pid, int status)
{
    printf("child %ld exit=%d\n", (long)pid, status); /* BUG: raw wait status */
}

int main(void)
{
    int log_fd = open("supervisor.log", O_CREAT | O_TRUNC | O_WRONLY, 0644);
    if (log_fd == -1) { perror("open"); return 1; }
    char fd_text[32];
    snprintf(fd_text, sizeof fd_text, "%d", log_fd);
    if (setenv("SUPERVISOR_FD", fd_text, 1) == -1) { perror("setenv"); return 1; }

    pid_t good = spawn_one("./worker_image", "7");
    pid_t missing = spawn_one("./worker_missing", "3");
    if (good == -1 || missing == -1) {
        fprintf(stderr, "BUG: pid=%ld fell through into supervisor control flow after spawn failure\n", (long)getpid());
        close(log_fd);
        return 1;
    }

    if (wait_until_both_zombie(good, missing) == -1) {
        fprintf(stderr, "fixture could not establish zombie checkpoint\n");
        close(log_fd);
        return 1;
    }

    printf("inspection window parent=%ld good=%ld missing=%ld log_fd=%d; inspect ps,/proc,strace evidence then press Enter\n",
           (long)getpid(), (long)good, (long)missing, log_fd);
    fflush(stdout);
    (void)getchar();

    /* BUG: children are never waited for. report_status() is unused and wrong. */
    (void)report_status;
    close(log_fd);
    return 0;
}
