#!/bin/bash
# REVIEWER-ONLY reference (never learner-facing).
MACHINE="-machine virt,highmem=off,gic-version=2"
CPU="-cpu cortex-a7"
MEM="-m 512M"
SMP="-smp 1"
DISPLAY_OPT="-nographic"
BOOTARGS="earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init"
qemu-system-arm $MACHINE $CPU $MEM $SMP $DISPLAY_OPT -kernel "$KERNEL" -initrd "$INITRD" -append "$BOOTARGS"
