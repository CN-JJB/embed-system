# P3-M02 Solution & Reference Evidence

> Reviewer Reference Only. Keep strictly isolated from learner files.

## 1. Rotated Challenge Solutions (`challenge/fixtures`)

### `candidate_effective.config`
- **Platform**: `CONFIG_ARCH_VIRT=y` (Pass).
- **Translation / Split Issue**: Configures `CONFIG_VMSPLIT_2G=y` and `CONFIG_PAGE_OFFSET=0x80000000`.
  - Consequence: Allocates 2 GB user virtual space and 2 GB kernel virtual space. Shifts `PAGE_OFFSET` from canonical `0xC0000000` down to `0x80000000`.
- **Serial Console Issue**: `CONFIG_SERIAL_AMBA_PL011=y` is set, but `# CONFIG_SERIAL_AMBA_PL011_CONSOLE is not set`.
  - Consequence: The PL011 driver is compiled, but no console is registered; `printk` messages will NOT appear on the terminal after architecture startup!

### `candidate_vmlinux` & `candidate_System.map`
- Entry Point: `0x80008000` (conforms to `PAGE_OFFSET = 0x80000000`).
- Symbol Synchronization: `stext`, `start_kernel`, and `rest_init` addresses in `candidate_System.map` strictly match `candidate_vmlinux`.

---

## 2. Rotated Gate Candidate Solutions (`gate/fixtures`)

### `gate_effective.config`
- Platform: `CONFIG_ARCH_VIRT=y`, `CONFIG_ARM_LPAE=n`, `CONFIG_VMSPLIT_3G=y`, `CONFIG_PAGE_OFFSET=0xC0000000`.
- Offending Config Symbol: `# CONFIG_SERIAL_EARLYCON is not set`.
  - Consequence: Early console output via `earlycon=pl011,...` is disabled. The system will appear completely hung during early boot until `console_init()` runs.

### `gate_zImage`
- Hex Magic at offset 0x24: `0x016f2818` (Little-endian bytes: `18 28 6f 01`).
- Verdict: Valid ARM Linux boot artifact header.

### `gate_vmlinux` vs `gate_System.map`
- `start_kernel`: `0xc0800000` in both (Pass).
- `console_init`: `0xc0800010` in `vmlinux`, but `0xc0809000` in `gate_System.map`!
- Verdict: **DRIFTED / STALE**. The symbol map represents an outdated compilation where symbol offsets have shifted.

---

## 3. Comprehensive Evaluation Rubric & Mapping

| Symptom / Question | Expected Evidence | Technical Interpretation | What It Does NOT Prove | Scoring |
|---|---|---|---|---|
| Config audit | Cat/grep of `candidate_effective.config` | Detects `CONFIG_VMSPLIT_2G` and disabled console | Does not prove whether kernel boots on target | 25 pts |
| zImage header audit | `hexdump -s 0x24 -n 4` showing `016f2818` | Validates official 32-bit ARM zImage magic | Does not prove kernel decompression or execution | 20 pts |
| Symbol drift audit | `readelf -s` vs `System.map` showing mismatch | Proves symbol table desynchronization (stale map) | Does not prove binary corruption | 20 pts |
| QEMU contract & flags | Mentions `highmem=off`, `gic-version=2`, `r2` DTB passing | Understands translation limits and ARM direct boot protocol | Does not prove host execution | 20 pts |
| Static portability boundary | Articulates CPU/ABI/syscall prerequisites | Static link removes `PT_INTERP`, but requires ABI compatibility | Does not guarantee universal execution | 15 pts |
