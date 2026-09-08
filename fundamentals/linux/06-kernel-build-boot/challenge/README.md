# P3-M02 Challenge — Effective Config Audit & Symbol Map Verification

> **AI Policy:** AI-Free first attempt. Use official Linux kernel docs and GNU Binutils.

## Problem Context
Your CI system has produced a compiled kernel candidate in `fixtures/`:
- `fixtures/candidate_effective.config`
- `fixtures/vmlinux_eval`
- `fixtures/System.map_eval`

Before loading this kernel into production QEMU test harnesses, you must audit its configuration and verify artifact synchronization.

## Your Task
1. Run `make all` in `challenge/` to generate the workspace.
2. Audit `fixtures/candidate_effective.config`:
   - Is `CONFIG_ARCH_VIRT` enabled?
   - Is `CONFIG_ARM_LPAE` strictly disabled (`=n` or not set)?
   - Is `CONFIG_VMSPLIT_3G` enabled, and what is `CONFIG_PAGE_OFFSET`?
   - Are serial drivers (`CONFIG_SERIAL_AMBA_PL011`, `CONFIG_SERIAL_EARLYCON`) enabled?
3. Inspect `fixtures/vmlinux_eval`:
   - Extract the entry point address using `readelf -h`.
   - Extract the virtual addresses of `stext`, `start_kernel`, and `rest_init` using `readelf -s` or `nm`.
4. Audit `fixtures/System.map_eval`:
   - Verify whether `System.map_eval` matches `vmlinux_eval` exactly or exhibits address drift.
5. Document your evidence with exact command outputs.
