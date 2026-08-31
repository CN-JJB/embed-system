
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <unistd.h>

static volatile sig_atomic_t stop_requested;

static void on_signal(int signo)
{
    (void)signo;
    stop_requested = 1;
}

int main(void)
{
    struct sigaction sa;

    sa.sa_handler = on_signal;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    if (sigaction(SIGINT, &sa, NULL) != 0 ||
        sigaction(SIGTERM, &sa, NULL) != 0) {
        perror("sigaction");
        return 1;
    }

    printf("ready pid=%ld\n", (long)getpid());
    fflush(stdout);

    while (!stop_requested) {
        if (pause() < 0 && errno != EINTR) {
            perror("pause");
            return 1;
        }
    }

    puts("normal-context cleanup complete");
    return 0;
}
