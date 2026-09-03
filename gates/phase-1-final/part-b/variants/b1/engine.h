#ifndef B1_ENGINE_H
#define B1_ENGINE_H

#include <stdint.h>
#include <stddef.h>

struct engine_event {
    uint64_t id;
    int32_t value;
    char *payload;
};

struct engine_window {
    struct engine_event events[16];
    size_t count;
    size_t capacity;
};

void engine_init(struct engine_window *win);
int engine_push_event(struct engine_window *win, uint64_t id, int32_t val, char *payload);
int engine_query_summary(const struct engine_window *win, int64_t *out_sum);
void engine_destroy(struct engine_window *win);

#endif /* B1_ENGINE_H */
