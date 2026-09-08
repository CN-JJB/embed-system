#!/bin/bash
set -euo pipefail

# Reviewer fixture generator for P3-M02 Challenge
# Kept isolated under reviewer/ to preserve AI-Free assessment validity.
# Materialized opaque fixtures are committed to the repo by the reviewer;
# learner workflows never execute this script.

OUT_DIR="${1:-fixtures}"
CROSS_COMPILE="${2:-arm-none-linux-gnueabihf-}"
CC="${CROSS_COMPILE}gcc"
NM="${CROSS_COMPILE}nm"
if ! command -v "$NM" >/dev/null 2>&1; then
    NM="nm"
fi

mkdir -p "$OUT_DIR"

# 1. Unfamiliar transfer config with subtle discrepancies (fresh variant)
cat << 'EOF' > "$OUT_DIR/candidate_effective.config"
# Candidate BSP Evaluation Config — Vendor Release 2026.09
# Target: ARMv7-A Cortex-A7 (virt platform evaluation)
CONFIG_ARCH_VIRT=y
# CONFIG_ARCH_VEXPRESS is not set
CONFIG_ARM_LPAE=y
CONFIG_VMSPLIT_3G=y
CONFIG_PAGE_OFFSET=0xC0000000
CONFIG_SERIAL_AMBA_PL011=y
CONFIG_SERIAL_AMBA_PL011_CONSOLE=y
CONFIG_SERIAL_EARLYCON=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_VIRTIO_MMIO=y
CONFIG_VIRTIO_BLK=y
CONFIG_EXT4_FS=y
# CONFIG_PRINTK is not set
EOF

# 2. Build candidate_vmlinux matching the canonical 3G/1G memory split
cat << 'EOF' > "$OUT_DIR/candidate_symbols.S"
/* SYNTHETIC PEDAGOGICAL STATIC FIXTURE — NOT A LINUX KERNEL BUILD */
	.arm
	.section .head.text, "ax"
	.globl stext
stext:
	b	__create_page_tables
	.size stext, .-stext

	.globl __create_page_tables
__create_page_tables:
	bx	lr

	.globl __enable_mmu
__enable_mmu:
	b	__mmap_switched

	.globl __mmap_switched
__mmap_switched:
	b	start_kernel

	.section .text, "ax"
	.globl start_kernel
start_kernel:
	bl	setup_arch
	bl	console_init
	b	rest_init

	.globl setup_arch
setup_arch:
	bx	lr

	.globl console_init
console_init:
	bx	lr

	.globl rest_init
rest_init:
	b	kernel_init

	.globl kernel_init
kernel_init:
	bx	lr
EOF

cat << 'EOF' > "$OUT_DIR/candidate_vmlinux.lds"
OUTPUT_ARCH(arm)
ENTRY(stext)
SECTIONS
{
	. = 0xC0008000;
	.head.text : { *(.head.text) }
	. = 0xC0800000;
	.text : { *(.text) }
	.rodata : { *(.rodata*) }
	.data : { *(.data*) }
	.bss : { *(.bss*) }
}
EOF

"$CC" -nostdlib -static -Wl,--build-id=none -T "$OUT_DIR/candidate_vmlinux.lds" -g "$OUT_DIR/candidate_symbols.S" -o "$OUT_DIR/candidate_vmlinux"

# 3. Generate candidate_System.map with a subtle address drift on one symbol
"$NM" -n "$OUT_DIR/candidate_vmlinux" | awk '{if ($3 == "console_init") print "c0807000", $2, $3; else print $1, $2, $3}' > "$OUT_DIR/candidate_System.map"

# Clean temporary intermediate files
rm -f "$OUT_DIR/candidate_symbols.S" "$OUT_DIR/candidate_vmlinux.lds"
