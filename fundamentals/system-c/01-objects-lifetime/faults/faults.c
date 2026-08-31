#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct packet_view {
    const uint8_t *data;
    size_t len;
};

static int fault_dangling(void)
{
    int *owner = malloc(sizeof *owner);
    if (owner == NULL) return 2;
    *owner = 73;
    int *borrowed = owner;
    free(owner);
    printf("borrowed value after owner release: %d\n", *borrowed); /* fault */
    return 0;
}

static unsigned checksum(struct packet_view v)
{
    unsigned sum = 0;
    for (size_t i = 0; i < v.len; ++i) sum += v.data[i];
    return sum;
}

static int fault_wrong_extent(void)
{
    uint8_t allocation[16];
    memset(allocation, 0xa5, sizeof allocation);
    allocation[0] = 1; allocation[1] = 2; allocation[2] = 3; allocation[3] = 4;

    const size_t logical_payload_len = 4;
    struct packet_view v = { allocation, sizeof allocation }; /* fault: contract says 4 */

    printf("logical_len=%zu advertised_len=%zu checksum=%u expected=%u\n",
           logical_payload_len, v.len, checksum(v), 10u);
    return 0;
}

static int fault_signed(void)
{
    volatile int samples = INT_MAX;
    int next = samples + 1; /* deliberate signed overflow */
    printf("next=%d\n", next);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "usage: %s dangling|wrong-extent|signed\n", argv[0]);
        return 2;
    }
    if (strcmp(argv[1], "dangling") == 0) return fault_dangling();
    if (strcmp(argv[1], "wrong-extent") == 0) return fault_wrong_extent();
    if (strcmp(argv[1], "signed") == 0) return fault_signed();
    fprintf(stderr, "unknown fault: %s\n", argv[1]);
    return 2;
}
