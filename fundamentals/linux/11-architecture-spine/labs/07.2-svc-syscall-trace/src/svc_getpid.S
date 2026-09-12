	.syntax unified
	.arch armv7-a
	.text
	.arm
	.global svc_getpid_raw
	.type svc_getpid_raw, %function
/* svc_getpid_raw — 最小的 ARM EABI 系统调用 (syscall) 存根.
 * 约定: r7 = syscall number (__NR_getpid = 20), svc #0 陷入内核 (trap).
 * 绝不经过 libc 包装: 即使 libc 存在 vDSO/优化捷径, 本对象仍保证执行 svc.
 */
svc_getpid_raw:
	mov	r7, #20		@ __NR_getpid
	svc	#0		@ trap into SVC / Supervisor (PL1)
	bx	lr		@ r0 holds return value (pid)
	.size svc_getpid_raw, .-svc_getpid_raw
/* Mark the stack non-executable so the linker/loader does not warn
 * "process ... started with executable stack" (a real defect observed on the
 * calibration kernel boot before this line was added). This must be the LAST
 * directive: it switches the current section and nothing may follow. */
	.section .note.GNU-stack,"",%progbits
