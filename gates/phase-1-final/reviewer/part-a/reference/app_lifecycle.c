#define _POSIX_C_SOURCE 200809L
#include "app_lifecycle.h"
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

int sifter_run_application_lifecycle(const struct sifter_io_config *cfg,
                                     struct sifter_stats *stats)
{
    if (cfg == NULL) {
        return -1;
    }

    int in_fd = STDIN_FILENO;
    int in_owned = 0;
    if (cfg->input_path != NULL && strcmp(cfg->input_path, "-") != 0) {
        in_fd = open(cfg->input_path, O_RDONLY | O_CLOEXEC);
        if (in_fd < 0) {
            return -1;
        }
        in_owned = 1;
    }

    int out_fd = STDOUT_FILENO;
    int out_owned = 0;
    if (cfg->output_path != NULL && strcmp(cfg->output_path, "-") != 0) {
        out_fd = open(cfg->output_path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
        if (out_fd < 0) {
            if (in_owned) {
                close(in_fd);
            }
            return -1;
        }
        out_owned = 1;
    }

    struct sifter_filter_ctx fctx = {
        .out_fd = out_fd,
        .threshold = cfg->filter_threshold,
        .emitted_records = 0
    };

    int res = sifter_process_stream(in_fd, sifter_filter_cb, &fctx, stats);

    if (in_owned) {
        close(in_fd);
    }
    if (out_owned) {
        close(out_fd);
    }

    return (res == 0) ? 0 : -1;
}
