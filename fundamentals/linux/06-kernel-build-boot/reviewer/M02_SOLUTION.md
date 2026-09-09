# P3-M02 Solution & Reference Evidence

> Reviewer Reference Only. Keep strictly isolated from learner files.

## 1. Challenge Reference (`challenge/fixtures`)

### `candidate_effective.config`
- **Platform**: `CONFIG_ARCH_VIRT=y` (Pass).
- **Translation Deviation**: `CONFIG_ARM_LPAE=y` is active.
  - Canonical Phase 3 freezes a non-LPAE 2-level short-descriptor baseline. Enabling LPAE deviates from the canonical translation-architecture contract.
- **Logging Deviation**: `# CONFIG_PRINTK is not set`.
  - Consequence: Kernel printk infrastructure is compiled out; early console/console messages cannot be relied upon for bring-up diagnostics.
- **Otherwise canonical**: `CONFIG_VMSPLIT_3G=y`, `CONFIG_PAGE_OFFSET=0xC0000000`, PL011 console chain and early console enabled, devtmpfs, virtio block and ext4 present.

### `candidate_vmlinux` & `candidate_System.map`
- Entry Point: `0xC0008000` (conforms to `PAGE_OFFSET = 0xC0000000`).
- Symbol Synchronization: `console_init` address in `candidate_System.map` is drifted (`0xc0807000`) while `candidate_vmlinux` places it elsewhere in `.text`; the other core boot symbols match.

---

## 2. Gate Reference (`gate/fixtures`)

### `gate_effective.config`
- Platform: `CONFIG_ARCH_VIRT=y`, `# CONFIG_ARM_LPAE is not set`, `CONFIG_VMSPLIT_3G=y`, `CONFIG_PAGE_OFFSET=0xC0000000`.
- Deviations:
  - `# CONFIG_VIRTIO_BLK is not set` — no virtio block driver for the QEMU virt root disk.
  - `# CONFIG_EXT4_FS is not set` — the planned root filesystem format is unavailable.
  - Consequence: Even if a rootfs device were attached, the kernel could not mount the planned ext4 root filesystem through virtio block.

### `gate_zImage`
- Hex Magic at offset 0x24: `0x016f2818` (Little-endian bytes: `18 28 6f 01`).
- Verdict: Valid ARM Linux boot artifact header.

### `gate_vmlinux` vs `gate_System.map`
- `kernel_init` address is drifted in `gate_System.map` (`0xc0809000`) while the binary places it elsewhere in `.text`.
- Verdict: **DRIFTED / STALE**. The symbol map represents an outdated compilation where symbol offsets have shifted.

---

## 3. Comprehensive Evaluation Rubric & Mapping

| Symptom / Question | Expected Evidence | Technical Interpretation | What It Does NOT Prove | Scoring |
|---|---|---|---|---|
| Config audit | Cat/grep of the delivered config | Detects every deviation from the canonical Phase 3 delta | Does not prove whether kernel boots on target | 25 pts |
| zImage header audit | `hexdump -s 0x24 -n 4` showing `016f2818` | Validates official 32-bit ARM zImage magic | Does not prove kernel decompression or execution | 20 pts |
| Symbol drift audit | `readelf -s`/`nm` vs `System.map` showing mismatch | Proves symbol table desynchronization (stale map) | Does not prove binary corruption | 20 pts |
| QEMU contract & flags | Mentions `highmem=off`, `gic-version=2`, `r2` DTB passing | Understands translation limits and ARM direct boot protocol | Does not prove host execution | 20 pts |
| Static portability boundary | Articulates CPU/ABI/syscall prerequisites | Static link removes `PT_INTERP`, but requires ABI compatibility | Does not guarantee universal execution | 15 pts |
