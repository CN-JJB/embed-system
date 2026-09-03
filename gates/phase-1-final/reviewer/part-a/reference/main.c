#define _POSIX_C_SOURCE 200809L
#include "app_lifecycle.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <limits.h>

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
            errno = 0;
            long val = strtol(argv[++i], &endptr, 10);
            if (*endptr != '\0' || errno == ERANGE || val < (long)INT32_MIN || val > (long)INT32_MAX) {
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

    struct sifter_io_config cfg = {
        .input_path = input_path,
        .output_path = output_path,
        .filter_threshold = filter_threshold
    };

    struct sifter_stats stats;
    int res = sifter_run_application_lifecycle(&cfg, &stats);
    if (res != 0) {
        fprintf(stderr, "Error: Application lifecycle execution failed\n");
        return 1;
    }

    if (show_stats) {
        fprintf(stderr, "[sifter] total=%zu valid=%zu filtered=%zu errors=%zu\n",
                stats.total_lines, stats.valid_records,
                stats.valid_records - stats.error_records, stats.error_records);
    }

    return 0;
}
