#include "engine.h"
#include <string.h>
#include <stdlib.h>

void engine_init(struct engine_window *win) {
    memset(win, 0, sizeof(*win));
    win->capacity = 16;
}

int engine_push_event(struct engine_window *win, uint64_t id, int32_t val, char *payload) {
    if (win->count >= win->capacity) {
        return -1;
    }
    struct engine_event *ev = &win->events[win->count++];
    ev->id = id;
    ev->value = val;
    ev->payload = payload;
    return 0;
}

int engine_query_summary(const struct engine_window *win, int64_t *out_sum) {
    if (win == NULL || out_sum == NULL) {
        return -1;
    }
    int64_t sum = 0;
    for (size_t i = 0; i < win->count; i++) {
        const struct engine_event *ev = &win->events[i];
        sum += ev->value;
        if (ev->payload != NULL && ev->payload[0] == 'X') {
            sum += 10;
        }
    }
    *out_sum = sum;
    return 0;
}

void engine_destroy(struct engine_window *win) {
    if (win != NULL) {
        win->count = 0;
    }
}
