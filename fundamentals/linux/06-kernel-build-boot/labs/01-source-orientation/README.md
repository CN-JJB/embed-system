# Lab 2.1 — Bounded Linux Source Orientation

## Objective
Read and trace the execution path connecting reset entry to `start_kernel()` in Linux 6.18.50 LTS without getting lost in 30 million lines of kernel source code.

## Key Files & Sections
1. `arch/arm/kernel/head.S`:
   - `stext`: Initial entry point in Supervisor (`SVC`) mode with MMU disabled.
   - `__create_page_tables`: Populates 16 KB Level 1 Translation Table (PGD) in physical RAM.
   - `__enable_mmu`: Writes CP15 `TTBR0`, `DACR`, sets `CR_M` bit in CP15 `SCTLR`.
   - `__mmap_switched`: Switches CPU execution to virtual memory (`0xC0000000`), sets up stack pointer `sp`, clears `.bss`, branches to `start_kernel`.
2. `init/main.c`:
   - `start_kernel()`: Core initialization sequence (`setup_arch()`, `mm_init()`, `trap_init()`, `console_init()`, `rest_init()`).
   - `rest_init()`: Spawns `kernel_init` thread (PID 1) and enters idle loop.
   - `kernel_init()`: Calls `try_to_run_init_process()` to launch `/sbin/init`.

## Run the Trace
```bash
bash trace_early_boot.sh
```
