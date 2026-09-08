#!/bin/bash
set -euo pipefail

# Trace the ARM early boot sequence through head.S and main.c

LINUX_SRC="${1:-${LINUX_SRC:-}}"
FIXTURES_SRC="../../fixtures/sources"

if [ -n "$LINUX_SRC" ] && [ -d "$LINUX_SRC" ]; then
    echo "Using real upstream Linux source at: $LINUX_SRC"
    bash ../../scripts/audit_source_orientation.sh "$LINUX_SRC"
    exit 0
fi

echo "--- 1. Pedagogical arch/arm/kernel/head.S Pseudocode (MMU OFF) ---"
grep -n -E "ENTRY\(stext\)|__create_page_tables|__enable_mmu|__mmap_switched|b\s+start_kernel" "${FIXTURES_SRC}/arch_arm_kernel_head_S.pseudocode"

echo ""
echo "--- 2. Pedagogical init/main.c Pseudocode (C Startup) ---"
grep -n -E "start_kernel\(|setup_arch\(|console_init\(|rest_init\(|kernel_init\(" "${FIXTURES_SRC}/init_main_c.pseudocode"

echo ""
echo "--- Boot Sequence Summary (Mental Model) ---"
echo "  [1] stext (MMU off): CPU in SVC mode, validates CPU MIDR, r2 holds DTB pointer"
echo "  [2] __create_page_tables: builds initial 16 KB L1 Page Directory in physical RAM"
echo "      (Note: UART mapped here ONLY under CONFIG_DEBUG_LL, not standard earlycon)"
echo "  [3] processor-specific setup (e.g. __v7_setup)"
echo "  [4] __enable_mmu / __turn_mmu_on: loads TTBR0, DACR, sets SCTLR CR_M bit, isb"
echo "  [5] __mmap_switched: sets up C stack pointer, clears BSS, jumps to start_kernel"
echo "  [6] start_kernel: setup_arch() consumes DTB boot data, earlycon/console_init() registers serial"
echo "  [7] rest_init: spawns kernel_init thread as PID 1, boot CPU enters idle loop"
echo "  [8] kernel_init: calls try_to_run_init_process to launch userspace (panics if no rootfs)"
echo "=== Trace Completed Successfully ==="
