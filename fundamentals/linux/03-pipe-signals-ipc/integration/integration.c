#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

struct record { char name[24]; long value; };
struct stats_ctx { size_t count; long sum; };
typedef int (*record_sink_fn)(const struct record *record, void *ctx);
static volatile sig_atomic_t stop_requested;

static void on_signal(int signo) { (void)signo; stop_requested = 1; }

static int stats_sink(const struct record *record, void *ctx)
{
    struct stats_ctx *stats = ctx;
    if (record == NULL || stats == NULL) return EINVAL;
    ++stats->count;
    stats->sum += record->value;
    printf("record: name=%s value=%ld\n", record->name, record->value);
    return 0;
}

static int parse_record(char *line, struct record *out)
{
    char *eq, *end;
    long value;
    if (line == NULL || out == NULL) return EINVAL;
    eq = strchr(line, '=');
    if (eq == NULL || eq == line || strlen(line) >= sizeof out->name + 24U) return EINVAL;
    *eq = '\0';
    if (strlen(line) >= sizeof out->name) return EINVAL;
    errno = 0;
    value = strtol(eq + 1, &end, 10);
    if (errno != 0 || end == eq + 1 || (*end != '\n' && *end != '\0')) return EINVAL;
    strcpy(out->name, line);
    out->value = value;
    return 0;
}

static int emit_line(char *line, record_sink_fn sink, void *ctx)
{
    struct record record;
    int rc = parse_record(line, &record);
    if (rc != 0) return rc;
    /* record is borrowed only for this synchronous call. */
    return sink(&record, ctx);
}

static int write_all(int fd, const char *buf, size_t len)
{
    size_t off = 0;
    while (off < len) {
        ssize_t n = write(fd, buf + off, len - off);
        if (n > 0) { off += (size_t)n; continue; }
        if (n < 0 && errno == EINTR) continue;
        return -1;
    }
    return 0;
}

static void producer_loop(int fd, int slow)
{
    static const char *const lines[] = {"temp=21\n", "temp=22\n", "voltage=5\n", "temp=23\n"};
    const struct timespec delay = {.tv_sec = 0, .tv_nsec = 100000000L};
    size_t rounds = slow ? 100U : 1U;
    for (size_t r = 0; r < rounds; ++r) {
        for (size_t i = 0; i < sizeof lines / sizeof lines[0]; ++i) {
            if (write_all(fd, lines[i], strlen(lines[i])) != 0) _exit(2);
            if (slow) (void)nanosleep(&delay, NULL);
        }
    }
    _exit(0);
}

static int install_handlers(void)
{
    struct sigaction sa;
    sa.sa_handler = on_signal;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    return sigaction(SIGTERM, &sa, NULL) == 0 && sigaction(SIGINT, &sa, NULL) == 0 ? 0 : -1;
}

int main(int argc, char **argv)
{
    int pipefd[2];
    pid_t producer;
    struct stats_ctx stats = {0U, 0};
    char line[96];
    size_t used = 0;
    int slow = argc == 2 && strcmp(argv[1], "--slow") == 0;
    int parse_failures = 0;
    int status;

    if ((argc > 2) || (argc == 2 && !slow)) { fprintf(stderr, "usage: %s [--slow]\n", argv[0]); return 2; }
    if (install_handlers() != 0 || pipe(pipefd) != 0) { perror("setup"); return 2; }

    producer = fork();
    if (producer < 0) { perror("fork"); (void)close(pipefd[0]); (void)close(pipefd[1]); return 2; }
    if (producer == 0) { (void)close(pipefd[0]); producer_loop(pipefd[1], slow); }

    (void)close(pipefd[1]);
    pipefd[1] = -1;
    while (!stop_requested) {
        char ch;
        ssize_t n = read(pipefd[0], &ch, 1U);
        if (n == 1) {
            if (used + 1U >= sizeof line) { fprintf(stderr, "line too long\n"); parse_failures = 1; break; }
            line[used++] = ch;
            if (ch == '\n') {
                line[used] = '\0';
                if (emit_line(line, stats_sink, &stats) != 0) { fprintf(stderr, "record rejected\n"); parse_failures = 1; }
                used = 0;
            }
            continue;
        }
        if (n == 0) break;
        if (errno == EINTR) { if (stop_requested) break; continue; }
        perror("read"); parse_failures = 1; break;
    }

    (void)close(pipefd[0]);
    if (stop_requested) (void)kill(producer, SIGTERM);
    while (waitpid(producer, &status, 0) < 0) {
        if (errno != EINTR) { perror("waitpid"); return 2; }
    }
    printf("stats: count=%zu sum=%ld stop=%s\n", stats.count, stats.sum, stop_requested ? "yes" : "no");
    return parse_failures ? 1 : 0;
}
