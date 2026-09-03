#ifndef SIFTER_APP_LIFECYCLE_H
#define SIFTER_APP_LIFECYCLE_H

#include "sifter.h"

struct sifter_io_config {
    const char *input_path;   /* NULL or "-" for borrowed STDIN */
    const char *output_path;  /* NULL or "-" for borrowed STDOUT */
    int32_t filter_threshold;
};

/*
 * Executes the complete application I/O and stream processing lifecycle:
 * 1. Opens owned input file descriptor (if input_path != NULL and != "-")
 * 2. Opens owned output file descriptor (if output_path != NULL and != "-")
 *    - If output opening fails, owned input descriptor is closed immediately.
 * 3. Invokes sifter_process_stream with sifter_filter_cb and threshold.
 * 4. Ensures all opened owned descriptors are explicitly closed on both success and failure paths.
 * 5. Guarantees borrowed descriptors (STDIN_FILENO, STDOUT_FILENO) are NEVER closed.
 *
 * Returns 0 on success, or non-zero error code.
 */
int sifter_run_application_lifecycle(const struct sifter_io_config *cfg,
                                     struct sifter_stats *stats);

#endif /* SIFTER_APP_LIFECYCLE_H */
