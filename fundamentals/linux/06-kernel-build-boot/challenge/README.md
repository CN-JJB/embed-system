# P3-M02 Challenge — Unfamiliar BSP Kernel Config & Artifact Triage

> **AI Policy:** Strict AI-Free first attempt. Use official Linux kernel documentation and GNU Binutils manuals.

## Problem Context
Your team has received an unfamiliar candidate kernel delivery from a hardware partner targeting an ARMv7-A Cortex-A7 QEMU virtual test harness.
The delivery contains:
- `fixtures/candidate_effective.config`
- `fixtures/candidate_vmlinux`
- `fixtures/candidate_System.map`

The vendor claims this build is ready for direct boot on `qemu-system-arm -machine virt,highmem=off,gic-version=2 -cpu cortex-a7`.
Before loading this kernel into test automation, you must audit its configuration and verify artifact synchronization.

## Your Tasks
1. Run `make all` in `challenge/` to generate the evaluation artifacts.
2. **Configuration Audit (`candidate_effective.config`)**:
   - Audit the platform target (`CONFIG_ARCH_VIRT`).
   - Audit the translation architecture: inspect the virtual memory split (`CONFIG_VMSPLIT_*`) and `CONFIG_PAGE_OFFSET`. Does this match standard 3G/1G or does it configure a 2G/2G split?
   - Audit the serial console drivers: are both `CONFIG_SERIAL_AMBA_PL011` and `CONFIG_SERIAL_AMBA_PL011_CONSOLE` enabled? What is the consequence if the console driver is disabled?
3. **vmlinux Artifact Inspection (`candidate_vmlinux`)**:
   - Run `readelf -h` to extract the machine architecture and ELF entry point.
   - Run `readelf -s` or `nm` to extract the virtual addresses of `stext`, `start_kernel`, `console_init`, and `rest_init`.
   - Confirm whether the entry point and symbols match the `PAGE_OFFSET` configured in the `.config`.
4. **Symbol Synchronization Audit (`candidate_System.map`)**:
   - Run `faults/F03-stale-system-map/diagnose_f03.sh candidate_vmlinux candidate_System.map` or manually cross-check `start_kernel`.
   - State whether the symbol map strictly synchronizes with the binary or exhibits address drift.
5. Provide your answers and command evidence in a clean diagnostic report.
