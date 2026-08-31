#include "span_u8.h"

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
    uint8_t a[] = {1, 2, 3, 4, 5};
    uint8_t b[5] = {0};
    struct span_u8 whole, mid, dst, empty;
    size_t copied = 99;

    assert(span_u8_make(a, sizeof a, &whole));
    assert(span_u8_make(NULL, 0, &empty));
    assert(!span_u8_make(NULL, 1, &empty));
    assert(span_u8_slice(whole, 1, 3, &mid));
    assert(mid.data == &a[1] && mid.len == 3);
    assert(!span_u8_slice(whole, 4, 2, &mid));
    assert(span_u8_make(b, sizeof b, &dst));
    assert(span_u8_copy(dst, whole, &copied));
    assert(copied == sizeof a && memcmp(a, b, sizeof a) == 0);
    assert(span_u8_compare(whole, dst) == 0);
    assert(span_u8_compare((struct span_u8){a, 3}, (struct span_u8){a, 4}) < 0);

    puts("span_u8 tests passed");
    return 0;
}
