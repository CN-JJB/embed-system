# P3-M02 Challenge — Unfamiliar BSP Kernel Config & Artifact Triage

> **AI Policy:** Strict AI-Free first attempt. Use official Linux kernel documentation and GNU Binutils manuals.

## Problem Context
Your team has received an unfamiliar candidate kernel delivery from a hardware partner targeting an ARMv7-A Cortex-A7 QEMU virtual test harness.
The delivery contains:
- `fixtures/candidate_effective.config`
- `fixtures/candidate_vmlinux`
- `fixtures/candidate_System.map`

The vendor claims this build is ready for direct boot on `qemu-system-arm -machine virt,highmem=off,gic-version=2 -cpu cortex-a7`.
Before loading this kernel into test automation, you must independently audit the delivered configuration and artifacts against the canonical Phase 3 platform rules.

## Your Tasks
1. Run `make all` in `challenge/` to verify the provisioned evaluation artifacts are in place.
2. **Configuration Audit (`candidate_effective.config`)**:
   - Audit the full effective configuration against the canonical Phase 3 platform rules documented in the module README (platform target, translation architecture, memory split / `PAGE_OFFSET`, serial console chain, early console, devtmpfs, virtio block, filesystem, printk).
   - Report **every deviation** from the canonical baseline with the exact config line as evidence.
   - Do not assume the config is correct: treat it as an unknown vendor delivery.
3. **vmlinux Artifact Inspection (`candidate_vmlinux`)**:
   - Run `readelf -h` to extract the machine architecture and ELF entry point.
   - Run `readelf -s` or `nm` to extract the virtual addresses of the core boot symbols.
   - Confirm whether the entry point and symbol layout are consistent with the `PAGE_OFFSET` configured in the delivered `.config`.
4. **Symbol Synchronization Audit (`candidate_System.map`)**:
   - Cross-check **every core boot symbol** (`stext`, `start_kernel`, `setup_arch`, `console_init`, `rest_init`, `kernel_init`) between `candidate_vmlinux` (via `readelf -s` or `nm`) and `candidate_System.map`.
   - `diagnose_f03.sh` checks only a fixed subset of symbols — do not treat it as a complete synchronization proof.
   - State whether the symbol map strictly synchronizes with the binary or exhibits address drift, with per-symbol evidence.
5. Provide your answers and command evidence in a clean diagnostic report.

> [!NOTE]
> Ground every conclusion in exact configuration lines and ELF/symbol-table evidence. A synthetic fixture proves only what the artifact files themselves contain — never infer runtime behavior from it.
