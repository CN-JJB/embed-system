#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static int static_object = 7;
int global_object_for_maps = 9;

static void marker_function(void)
{
}

static void locate(const char *label, uintptr_t addr)
{
    FILE *fp = fopen("/proc/self/maps", "r");
    char line[512];

    if (fp == NULL) {
        perror("/proc/self/maps");
        exit(EXIT_FAILURE);
    }

    while (fgets(line, sizeof line, fp) != NULL) {
        uintptr_t lo = 0;
        uintptr_t hi = 0;
        if (sscanf(line, "%" SCNxPTR "-%" SCNxPTR, &lo, &hi) == 2
            && addr >= lo && addr < hi) {
            printf("%-10s 0x%" PRIxPTR " -> %s", label, addr, line);
            fclose(fp);
            return;
        }
    }

    printf("%-10s 0x%" PRIxPTR " -> mapping not found\n", label, addr);
    fclose(fp);
}

int main(void)
{
    int stack_local = 11;
    int *heap_object = malloc(sizeof *heap_object);
    if (heap_object == NULL) {
        perror("malloc");
        return EXIT_FAILURE;
    }
    *heap_object = 13;

    uintptr_t fn_addr = (uintptr_t)&marker_function;
    locate("function", fn_addr);
    locate("static", (uintptr_t)&static_object);
    locate("global", (uintptr_t)&global_object_for_maps);
    locate("stack", (uintptr_t)&stack_local);
    locate("heap", (uintptr_t)heap_object);

    puts("\n--- /proc/self/maps ---");
    FILE *fp = fopen("/proc/self/maps", "r");
    if (fp != NULL) {
        char line[512];
        while (fgets(line, sizeof line, fp) != NULL)
            fputs(line, stdout);
        fclose(fp);
    }

    free(heap_object);
    return 0;
}
