/* Lab 7.3 / F13 kfault — 受控的内核地址访问故障 (controlled kernel-address fault).
 *
 * 在冻结的 3G/1G 切分下 (CONFIG_VMSPLIT_3G=y, PAGE_OFFSET=0xC0000000),
 * 用户态 (PL0, User mode) 直接解引用 >= 0xC0000000 的地址必须 fault.
 * 演示地址 0xC0008000 落在内核虚地址范围 (kernel virtual range) 内,
 * 仅用作“用户态不能碰内核半区”的证据, 不声称对应任何物理地址.
 *
 * 预期: 进程收到 SIGSEGV (userspace fault/signal), 程序按预期路径退出.
 * 注意: 具体 dmesg 文本未校准 (UNVERIFIED), 实验中不得硬编码匹配某行 dmesg.
 *
 * 构建 (硬浮点工具链须补 -mfpu 与 -mfloat-abi=hard):
 *   arm-none-linux-gnueabihf-gcc -static -march=armv7-a -mfpu=vfpv4-d16 \
 *     -mfloat-abi=hard -marm -O0 -g -o kfault.elf kfault.c
 */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define KFAULT_DEMO_ADDR ((volatile unsigned char *)0xC0008000UL)

static void on_segv(int sig)
{
    (void)sig;
    printf("caught SIGSEGV: userspace fault on kernel-range access (EXPECTED)\n");
    printf("proves: PL0 cannot dereference kernel half; does NOT prove any physical mapping\n");
    /* _exit() skips stdio flush: the two lines above would be silently lost
     * when stdout is a pipe/file (exactly the QEMU -nographic capture case).
     * Flush before _exit so the learner's primary evidence actually appears. */
    fflush(stdout);
    _exit(42);
}

int main(void)
{
    volatile unsigned char v;

    signal(SIGSEGV, on_segv);
    printf("pid=%ld attempting controlled read of %p (>= PAGE_OFFSET 0xC0000000)\n",
           (long)getpid(), (void *)KFAULT_DEMO_ADDR);
    fflush(stdout);

    /* 受控访问: 期望在此处触发 SIGSEGV, 由上面的 handler 接住. */
    v = *KFAULT_DEMO_ADDR;

    /* 若执行到这里, 说明假设被违反, 必须显式报告而非沉默通过. */
    printf("UNEXPECTED: read returned 0x%02x without fault (investigate split/permissions)\n", v);
    return 1;
}
