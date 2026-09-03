#define _POSIX_C_SOURCE 200809L
#include "sifter.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

int main(int argc, char **argv) {
    const char *input_path = NULL;
    const char *output_path = NULL;
    int32_t filter_threshold = 0;
    int show_stats = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--input") == 0 && i + 1 < argc) {
            input_path = argv[++i];
        } else if (strcmp(argv[i], "--output") == 0 && i + 1 < argc) {
            output_path = argv[++i];
        } else if (strcmp(argv[i], "--filter") == 0 && i + 1 < argc) {
            char *endptr = NULL;
            long val = strtol(argv[++i], &endptr, 10);
            if (*endptr != '\0') {
                fprintf(stderr, "Error: Invalid filter threshold '%s'\n", argv[i]);
                return 1;
            }
            filter_threshold = (int32_t)val;
        } else if (strcmp(argv[i], "--stats") == 0) {
            show_stats = 1;
        } else {
            fprintf(stderr, "Usage: %s [--input PATH|-] [--filter THRESHOLD] [--output PATH|-] [--stats]\n", argv[0]);
            return 1;
        }
    }

    int in_fd = STDIN_FILENO;
    int in_owned = 0;
    if (input_path != NULL && strcmp(input_path, "-") != 0) {
        in_fd = open(input_path, O_RDONLY | O_CLOEXEC);
        if (in_fd < 0) {
            fprintf(stderr, "Error: Failed to open input file '%s': %s\n", input_path, strerror(errno));
            return 1;
        }
        in_owned = 1;
    }

    int out_fd = STDOUT_FILENO;
    int out_owned = 0;
    if (output_path != NULL && strcmp(output_path, "-") != 0) {
        out_fd = open(output_path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
        if (out_fd < 0) {
            fprintf(stderr, "Error: Failed to open output file '%s': %s\n", output_path, strerror(errno));
            if (in_owned) {
                close(in_fd);
            }
            return 1;
        }
        out_owned = 1;
    }

    struct sifter_stats stats;
    int res = sifter_process_stream(in_fd, out_fd, filter_threshold, &stats);

    if (in_owned) {
        close(in_fd);
    }
    if (out_owned) {
        close(out_fd);
    }

    if (res != 0) {
        fprintf(stderr, "Error during stream processing\n");
        return 1;
    }

    if (show_stats) {
        fprintf(stderr, "[sifter] total=%zu valid=%zu filtered=%zu errors=%zu\n",
                stats.total_lines, stats.valid_records,
                stats.filtered_records, stats.error_records);
    }

    return 0;
}
