/* Lab 7.2 调用包装 (wrapper): 对比裸 svc 与 libc getpid.
 *
 * 构建 (硬浮点工具链须补 -mfpu 与 -mfloat-abi=hard):
 *   arm-none-linux-gnueabihf-gcc -static -march=armv7-a -mfpu=vfpv4-d16 \
 *     -mfloat-abi=hard -marm -O0 -g -o svc_getpid.elf svc_main.c svc_getpid.S
 * 反汇编证明 (disassembly proof, Lab 7.2 的核心证据):
 *   arm-none-linux-gnueabihf-objdump -d svc_getpid.elf | grep -A6 '<svc_getpid_raw>'
 * 必须看到 `svc 0x00000000`; 看不到即不满足 Lab 要求.
 */
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>

#include "svc_getpid.h"

int main(void)
{
    long raw_pid = svc_getpid_raw();
    pid_t libc_pid = getpid();

    printf("raw svc getpid : %ld\n", raw_pid);
    printf("libc getpid    : %ld\n", (long)libc_pid);
    printf("match          : %s\n", raw_pid == (long)libc_pid ? "yes" : "NO (investigate)");
    return 0;
}
