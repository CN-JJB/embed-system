#include "../challenge/span_u8.h"

#include <string.h>

bool span_u8_make(uint8_t *data, size_t len, struct span_u8 *out)
{
    if (out == NULL || (data == NULL && len != 0)) return false;
    *out = (struct span_u8){data, len};
    return true;
}

bool span_u8_slice(struct span_u8 src, size_t offset, size_t len,
                   struct span_u8 *out)
{
    if (out == NULL || (src.data == NULL && src.len != 0)) return false;
    if (offset > src.len || len > src.len - offset) return false;
    if (len == 0 && src.data == NULL) {
        *out = (struct span_u8){NULL, 0};
    } else {
        *out = (struct span_u8){src.data + offset, len};
    }
    return true;
}

bool span_u8_copy(struct span_u8 dst, struct span_u8 src, size_t *copied)
{
    if (copied == NULL) return false;
    *copied = 0;
    if ((dst.data == NULL && dst.len != 0) || (src.data == NULL && src.len != 0)) return false;
    if (dst.len < src.len) return false;
    if (src.len != 0) memmove(dst.data, src.data, src.len);
    *copied = src.len;
    return true;
}

int span_u8_compare(struct span_u8 a, struct span_u8 b)
{
    size_t common = a.len < b.len ? a.len : b.len;
    int r = common ? memcmp(a.data, b.data, common) : 0;
    if (r != 0) return r;
    return (a.len > b.len) - (a.len < b.len);
}
