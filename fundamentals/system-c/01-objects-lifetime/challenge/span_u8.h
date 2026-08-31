#ifndef SPAN_U8_H
#define SPAN_U8_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

struct span_u8 {
    uint8_t *data;
    size_t len;
};

bool span_u8_make(uint8_t *data, size_t len, struct span_u8 *out);
bool span_u8_slice(struct span_u8 src, size_t offset, size_t len,
                   struct span_u8 *out);
bool span_u8_copy(struct span_u8 dst, struct span_u8 src, size_t *copied);
int span_u8_compare(struct span_u8 a, struct span_u8 b);

#endif
