/*
 * Synthetic Pedagogical Kernel Image Artifact for P3-M02
 * Implements real ARMv7-A symbols at PAGE_OFFSET (0xC0000000)
 */

	.arm
	.section .head.text, "ax"
	.globl stext
	.type stext, %function
stext:
	b	__create_page_tables
	.size stext, .-stext

	.globl __create_page_tables
	.type __create_page_tables, %function
__create_page_tables:
	bx	lr
	.size __create_page_tables, .-__create_page_tables

	.globl __enable_mmu
	.type __enable_mmu, %function
__enable_mmu:
	b	__mmap_switched
	.size __enable_mmu, .-__enable_mmu

	.globl __mmap_switched
	.type __mmap_switched, %function
__mmap_switched:
	b	start_kernel
	.size __mmap_switched, .-__mmap_switched

	.section .text, "ax"
	.globl start_kernel
	.type start_kernel, %function
start_kernel:
	bl	setup_arch
	bl	console_init
	b	rest_init
	.size start_kernel, .-start_kernel

	.globl setup_arch
	.type setup_arch, %function
setup_arch:
	bx	lr
	.size setup_arch, .-setup_arch

	.globl console_init
	.type console_init, %function
console_init:
	bx	lr
	.size console_init, .-console_init

	.globl rest_init
	.type rest_init, %function
rest_init:
	b	kernel_init
	.size rest_init, .-rest_init

	.globl kernel_init
	.type kernel_init, %function
kernel_init:
	b	try_to_run_init_process
	.size kernel_init, .-kernel_init

	.globl try_to_run_init_process
	.type try_to_run_init_process, %function
try_to_run_init_process:
	bx	lr
	.size try_to_run_init_process, .-try_to_run_init_process

	.section .rodata
	.globl linux_banner
linux_banner:
	.asciz "Linux version 6.18.50 (arm-none-linux-gnueabihf-gcc) #1 SMP PREEMPT Tue Sep 8 09:00:00 UTC 2026\n"
