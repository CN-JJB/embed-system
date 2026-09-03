#define _POSIX_C_SOURCE 200809L
#include "spool.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <dirent.h>

static void timeout_handler(int sig) {
    (void)sig;
    const char msg[] = "\n>>> TIMEOUT: B2 harness exceeded safety watchdog timer! <<<\n";
    write(STDERR_FILENO, msg, sizeof(msg) - 1);
    _exit(2);
}

static int count_open_fds(void) {
    DIR *d = opendir("/proc/self/fd");
    if (!d) {
        return -1;
    }
    int count = 0;
    struct dirent *ent;
    while ((ent = readdir(d)) != NULL) {
        if (ent->d_name[0] != '.') {
            count++;
        }
    }
    closedir(d);
    return count;
}

int main(void) {
    printf("=== Starting B2 Test Harness ===\n");
    signal(SIGALRM, timeout_handler);
    alarm(3);

    int base_fds = count_open_fds();
    printf("[harness] Baseline active FDs: %d\n", base_fds);

    struct spool_manager mgr;
    if (spool_init(&mgr, "/tmp/b2_test_init.log") != 0) {
        fprintf(stderr, "Failed to init spooler\n");
        return 1;
    }

    /* Execute 10 rotation cycles */
    for (int i = 0; i < 10; i++) {
        char path[64];
        snprintf(path, sizeof(path), "/tmp/b2_test_%d.log", i);
        spool_write(&mgr, "test_log_data\n", 14);
        if (spool_rotate(&mgr, path) != 0) {
            fprintf(stderr, "Rotation %d failed\n", i);
            spool_close(&mgr);
            return 1;
        }
    }

    spool_close(&mgr);

    int final_fds = count_open_fds();
    printf("[harness] Post-rotation active FDs: %d (baseline was %d)\n", final_fds, base_fds);

    /* Clean up temporary test files */
    unlink("/tmp/b2_test_init.log");
    for (int i = 0; i < 10; i++) {
        char path[64];
        snprintf(path, sizeof(path), "/tmp/b2_test_%d.log", i);
        unlink(path);
    }

    /* In a correct implementation, final_fds should match baseline */
    if (final_fds > base_fds + 1) {
        fprintf(stderr, ">>> FAULT DETECTED: Descriptor table growth detected (%d leaked descriptors)! <<<\n",
                final_fds - base_fds);
        return 1;
    }

    printf(">>> SUCCESS: Descriptors reclaimed cleanly <<<\n");
    alarm(0);
    return 0;
}
