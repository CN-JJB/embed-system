#!/bin/bash
# Opaque Gate starter configuration (reviewer-authored).
# This starter is NOT canonical: diagnose it against the module contract,
# author the canonical candidate independently, and prove it with a fresh
# QEMU capture. Copying these lines verbatim cannot pass.
MACHINE="-machine virt,highmem=off,gic-version=2"
CPU="-cpu cortex-a7"
MEM="-m 256M"
SMP="-smp 1"
DISPLAY_OPT="-nographic"
BOOTARGS="earlycon=pl011,0x09000000 console=ttyAMA0,115200 console=ttyAMA0 rdinit=/sbin/init"
qemu-system-arm $MACHINE $CPU $MEM $SMP $DISPLAY_OPT -kernel "$KERNEL" -initrd "$INITRD" -append "$BOOTARGS"
