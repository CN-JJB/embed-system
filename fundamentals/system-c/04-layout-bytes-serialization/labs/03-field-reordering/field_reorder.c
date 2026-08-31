#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

struct semantic_one { uint8_t type; uint32_t value; uint16_t flags; };
struct semantic_two { uint32_t value; uint16_t flags; uint8_t type; };

int main(void)
{
    printf("one size=%zu offsets=%zu,%zu,%zu\n", sizeof(struct semantic_one), offsetof(struct semantic_one,type), offsetof(struct semantic_one,value), offsetof(struct semantic_one,flags));
    printf("two size=%zu offsets=%zu,%zu,%zu\n", sizeof(struct semantic_two), offsetof(struct semantic_two,type), offsetof(struct semantic_two,value), offsetof(struct semantic_two,flags));
    return 0;
}
