#!/bin/bash
set -euo pipefail

# Trace the ARM early boot sequence through head.S and main.c

FIXTURES_SRC="../../fixtures/sources"

echo "=== Bounded Linux Source Reading Trace ==="
echo "Upstream baseline: Linux 6.18.50 LTS (commit 7cfc41f8e80f11ffa8382ed1a505154ceffb79c7)"
echo ""

echo "--- 1. arch/arm/kernel/head.S (Assembly Early Boot, MMU OFF) ---"
grep -n -E "ENTRY\(stext\)|__create_page_tables|__enable_mmu|__mmap_switched|b\s+start_kernel" "${FIXTURES_SRC}/arch_arm_kernel_head_S.excerpt"

echo ""
echo "--- 2. init/main.c (Architecture-Independent C Startup) ---"
grep -n -E "start_kernel\(|setup_arch\(|console_init\(|rest_init\(|kernel_init\(|try_to_run_init_process\(" "${FIXTURES_SRC}/init_main_c.excerpt"

echo ""
echo "--- Boot Sequence Summary ---"
echo "  [1] Entry at stext with MMU=OFF, D-cache=OFF, r2=DTB pointer"
echo "  [2] __create_page_tables: builds initial 16 KB Level 1 Page Directory in physical RAM"
echo "  [3] __enable_mmu: programs CP15 TTBR0, DACR, sets CR_M in SCTLR, barriers"
echo "  [4] __mmap_switched: sets up C stack pointer, clears BSS, jumps to start_kernel"
echo "  [5] start_kernel: setup_arch() consumes DTB boot data, earlycon/console_init() registers serial"
echo "  [6] rest_init: spawns kernel_init thread as PID 1, boot CPU enters idle loop"
echo "  [7] kernel_init: calls try_to_run_init_process to launch userspace"
echo "=== Trace Completed Successfully ==="
