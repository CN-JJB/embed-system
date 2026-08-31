#include "span_u8.h"

/* AI-Free starter: replace the conservative stubs with your implementation. */
bool span_u8_make(uint8_t *data, size_t len, struct span_u8 *out)
{
    (void)data; (void)len; (void)out;
    return false;
}

bool span_u8_slice(struct span_u8 src, size_t offset, size_t len,
                   struct span_u8 *out)
{
    (void)src; (void)offset; (void)len; (void)out;
    return false;
}

bool span_u8_copy(struct span_u8 dst, struct span_u8 src, size_t *copied)
{
    (void)dst; (void)src; (void)copied;
    return false;
}

int span_u8_compare(struct span_u8 a, struct span_u8 b)
{
    (void)a; (void)b;
    return 0;
}
