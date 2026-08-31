#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static int proc_state(pid_t pid, char *state)
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

static int wait_for_zombie(pid_t child)
{
    struct timespec pause = {.tv_sec = 0, .tv_nsec = 10 * 1000 * 1000};
    for (int i = 0; i < 500; ++i) {
        char state;
        if (proc_state(child, &state) == 0 && state == 'Z') return 0;
        nanosleep(&pause, NULL);
    }
    return -1;
}

int main(void)
{
    pid_t child = fork();
    if (child == -1) { perror("fork"); return 1; }
    if (child == 0) _exit(42);

    if (wait_for_zombie(child) == -1) {
        fprintf(stderr, "failed to observe child enter Z state\n");
        return 1;
    }

    printf("zombie checkpoint: parent=%ld child=%ld; inspect ps and /proc, then press Enter\n",
           (long)getpid(), (long)child);
    fflush(stdout);
    (void)getchar();

    int status;
    if (waitpid(child, &status, 0) == -1) { perror("waitpid"); return 1; }
    if (WIFEXITED(status)) printf("reaped child=%ld exit=%d\n", (long)child, WEXITSTATUS(status));

    char state;
    if (proc_state(child, &state) == -1 && errno == ENOENT) puts("/proc child entry is gone after reap");
    else puts("check /proc manually: child entry should be gone after reap");
    return 0;
}
