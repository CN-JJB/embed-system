#ifndef PARSER_H
#define PARSER_H
#include <signal.h>
#include "telemetry.h"

typedef int (*record_sink_fn)(const struct telemetry_record *record, void *ctx);
enum parser_status { PARSER_OK=0, PARSER_INVALID=2, PARSER_IO=3, PARSER_SINK=4, PARSER_STOPPED=5 };
int parse_text_fd(int fd, record_sink_fn sink, void *ctx, volatile sig_atomic_t *stop_requested);
#endif
