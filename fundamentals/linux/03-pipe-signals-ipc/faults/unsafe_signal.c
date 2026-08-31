
#define _POSIX_C_SOURCE 200809L
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static char *application_state;
static int application_fd = -1;

static void bad_handler(int signo)
{
    printf("signal=%d cleanup now\n", signo);
    free(application_state);
    if (application_fd >= 0) close(application_fd);
    application_state = NULL;
    application_fd = -1;
}

int main(void)
{
    struct sigaction sa;
    int p[2];

    application_state = malloc(64);
    if (application_state == NULL) return 1;
    if (pipe(p) != 0) {
        free(application_state);
        return 1;
    }
    application_fd = p[0];
    close(p[1]);

    sa.sa_handler = bad_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    if (sigaction(SIGTERM, &sa, NULL) != 0) return 1;

    printf("unsafe_fixture_pid=%ld\n", (long)getpid());
    fflush(stdout);
    pause();

    /* Runtime survival does not validate the handler design. */
    if (application_state != NULL) free(application_state);
    if (application_fd >= 0) close(application_fd);
    return 0;
}
