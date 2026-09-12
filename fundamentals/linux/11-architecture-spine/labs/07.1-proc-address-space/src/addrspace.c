/* Lab 7.1 addrspace — 打印进程地址空间 (process address space) 样本.
 *
 * 目的: 观察同一进程内的四类虚地址 (virtual address):
 *   函数/.text (function/text), 全局/静态对象 (global/static),
 *   堆分配 (heap), 栈变量 (stack).
 * 学习者将打印出的地址与 /proc/self/maps 相关联 (correlate),
 * 并理解 maps 只证明虚拟映射, 不证明物理地址 (NOT physical proof).
 *
 * 构建 (canonical toolchain; 硬浮点工具链须补 -mfpu 与 -mfloat-abi=hard,
 * 否则报 "-mfloat-abi=hard: selected architecture lacks an FPU"):
 *   arm-none-linux-gnueabihf-gcc -static -march=armv7-a -mfpu=vfpv4-d16 \
 *     -mfloat-abi=hard -marm -O0 -g -o addrspace.elf addrspace.c
 * 主机冒烟 (可选, 只证明逻辑, 不证明目标行为):
 *   gcc -O0 -g -o addrspace.host addrspace.c && ./addrspace.host
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

/* 全局对象, 落在 data/bss 段的可写映射中. */
static int g_counter = 42;
static int g_bss_zero;

static void sample_function(void)
{
}

int main(void)
{
    int stack_var = 0;
    void *heap = malloc(64);
    FILE *fp;
    char line[512];

    if (!heap) {
        printf("malloc failed\n");
        return 1;
    }

    /* 本进程 pid: /proc/self/maps 即 /proc/<pid>/maps 的自身引用. */
    printf("pid            : %ld\n", (long)getpid());
    printf("func   .text  : %p\n", (void *)sample_function);
    printf("global data   : %p\n", (void *)&g_counter);
    printf("global bss    : %p\n", (void *)&g_bss_zero);
    printf("heap  malloc  : %p\n", heap);
    printf("stack local   : %p\n", (void *)&stack_var);
    printf("TASK_SIZE guard: user addresses must be < 0xBF000000\n");
    printf("PAGE_OFFSET    : 0xC0000000 (frozen 3G/1G split, VMSPLIT_3G)\n");

    /* 直接转储本进程 maps (/proc/self == /proc/<pid>), 便于与上面地址逐行对照. */
    fp = fopen("/proc/self/maps", "r");
    if (fp) {
        printf("---- /proc/self/maps ----\n");
        while (fgets(line, sizeof(line), fp))
            fputs(line, stdout);
        fclose(fp);
    } else {
        printf("cannot open /proc/self/maps (non-Linux host?)\n");
    }

    free(heap);
    return 0;
}
