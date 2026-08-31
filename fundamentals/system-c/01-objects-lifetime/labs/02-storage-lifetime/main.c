#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int file_static = 11;
int global_object = 22;

static void show_mapping(const char *label, uintptr_t addr)
{
    FILE *fp = fopen("/proc/self/maps", "r");
    char line[512];

    if (fp == NULL) {
        perror("fopen /proc/self/maps");
        return;
    }

    while (fgets(line, sizeof line, fp) != NULL) {
        uintptr_t lo = 0;
        uintptr_t hi = 0;
        if (sscanf(line, "%" SCNxPTR "-%" SCNxPTR, &lo, &hi) == 2
            && addr >= lo && addr < hi) {
            printf("mapping %-12s: %s", label, line);
            break;
        }
    }
    fclose(fp);
}

static void observe_scope(void)
{
    int automatic = 33;
    static int local_static = 44;
    int *allocated = malloc(sizeof *allocated);

    if (allocated == NULL) {
        perror("malloc");
        exit(EXIT_FAILURE);
    }
    *allocated = 55;

    printf("event: enter observe_scope\n");
    printf("automatic      %p value=%d\n", (void *)&automatic, automatic);
    printf("local static   %p value=%d\n", (void *)&local_static, local_static);
    printf("file static    %p value=%d\n", (void *)&file_static, file_static);
    printf("global         %p value=%d\n", (void *)&global_object, global_object);
    printf("heap allocation%p value=%d\n", (void *)allocated, *allocated);

    show_mapping("automatic", (uintptr_t)&automatic);
    show_mapping("local-static", (uintptr_t)&local_static);
    show_mapping("global", (uintptr_t)&global_object);
    show_mapping("allocated", (uintptr_t)allocated);

    printf("event: free allocated storage at %p\n", (void *)allocated);
    free(allocated);
    printf("event: leave observe_scope; automatic lifetime ends\n");
}

int main(void)
{
    observe_scope();
    puts("event: process still alive; static-storage objects still have lifetime");
    return 0;
}
