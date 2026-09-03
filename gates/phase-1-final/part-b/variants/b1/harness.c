#define _POSIX_C_SOURCE 200809L
#include "engine.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>

static void timeout_handler(int sig) {
    (void)sig;
    const char msg[] = "\n>>> TIMEOUT: B1 harness exceeded safety watchdog timer! <<<\n";
    write(STDERR_FILENO, msg, sizeof(msg) - 1);
    _exit(2);
}

int main(void) {
    printf("=== Starting B1 Test Harness ===\n");
    signal(SIGALRM, timeout_handler);
    alarm(3);

    struct engine_window win;
    engine_init(&win);

    /* Process initial telemetry batch */
    for (uint64_t i = 0; i < 5; i++) {
        char *batch_buf = malloc(32);
        if (batch_buf == NULL) {
            return 1;
        }
        snprintf(batch_buf, 32, "X_event_payload_%lu", (unsigned long)i);
        engine_push_event(&win, i, (int32_t)(i * 10), batch_buf);
        free(batch_buf);
    }

    printf("[harness] Ingested 5 batch events. Querying window summary...\n");
    fflush(stdout);

    int64_t total = 0;
    int res = engine_query_summary(&win, &total);
    printf("[harness] Query completed with result code %d, total: %ld\n", res, (long)total);

    engine_destroy(&win);
    alarm(0);
    return 0;
}
