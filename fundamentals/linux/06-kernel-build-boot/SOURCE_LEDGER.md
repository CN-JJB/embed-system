# P3-M02 Source Ledger — Linux Kernel Build & Boot Flow

> Checked: **2026-09-08**.  
> Primary kernel source baseline: **Linux 6.18.50 LTS** (tag `v6.18.50`, peeled commit `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7`).  
> Primary emulation baseline: **QEMU 11.1.1** (tag `v11.1.1`, peeled commit `c3d48b7d1e89604920e5b81b91140c2ad39a1943`).  
> Primary toolchain baseline: **Arm GNU Toolchain 13.3.rel1** (`arm-none-linux-gnueabihf-`).

---

## 1. Upstream & Specification Traceability Table

| ID | Source / Artifact | Organization / Author | Type | Path / Exact Section | Version / Tag / Commit | Upstream URL / Origin | Checked Date | Teaching Purpose | Risk / Constraints |
|---|---|---|---|---|---|---|---|---|---|
| M02-S01 | Linux Kernel Source Tree | Linux Kernel Community | Official Upstream Git | `arch/arm/kernel/head.S` | **Linux 6.18.50 LTS** (tag `v6.18.50`, commit `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7`) | `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git` | 2026-09-08 | Trace `stext`, `__create_page_tables`, `__enable_mmu`, `__mmap_switched` | Canonical boot assembly |
| M02-S02 | Linux Kernel Initialization | Linux Kernel Community | Official Upstream Git | `init/main.c` | **Linux 6.18.50 LTS** (same commit) | `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git` | 2026-09-08 | Trace `start_kernel()`, `setup_arch()`, `console_init()`, `rest_init()`, `kernel_init()` | Canonical C entry point |
| M02-S03 | ARM Kernel Configuration Baseline | Linux Kernel Community | Official Upstream Git | `arch/arm/configs/multi_v7_defconfig` | **Linux 6.18.50 LTS** (same commit) | `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git` | 2026-09-08 | Baseline configuration enabling `CONFIG_ARCH_VIRT=y` | Rejects `vexpress_defconfig` |
| M02-S04 | QEMU System Emulator | QEMU Project | Official Upstream Git | `docs/system/arm/virt.rst`, `hw/arm/virt.c` | **QEMU 11.1.1** (tag `v11.1.1`, commit `c3d48b7d1e89604920e5b81b91140c2ad39a1943`) | `https://gitlab.com/qemu-project/qemu.git` | 2026-09-08 | Canonical launch contract `-machine virt,highmem=off,gic-version=2 -cpu cortex-a7 -m 512M -smp 1 -nographic` | Highmem non-LPAE contract |
| M02-S05 | Kconfig Language Specification | Linux Kernel Documentation | Upstream Documentation | `Documentation/kbuild/kconfig-language.rst` | **Linux 6.18.50 LTS** | Official docs | 2026-09-08 | Mental model of Kconfig menus, config dependencies, and default values | Low |
| M02-S06 | ARM Architecture Reference Manual | Arm Ltd. | Official Hardware Specification | ARMv7-A/R Architecture Manual (ARM DDI 0406C.d) | Section B3 (VMSA Short-Descriptor Page Tables) | Arm Ltd. Documentation | 2026-09-08 | Explains why `CONFIG_ARM_LPAE=n` enforces 2-level translation | Authoritative hardware reference |
| M02-S07 | Phase 3 Curriculum Design | This Repository | Canonical Curriculum Architecture | `research/phase-3/2026-09-08-embedded-linux-curriculum-design.md` | Commit `200c46f69c1664cd28784573148add0f637c4f9a` | `roadmap/phase-3-embedded-linux.md` | 2026-09-08 | Canonical 4.0 h MUST budget, F03 fault, gate requirements | Repository canonical |
| M02-S08 | Arm GNU Toolchain | Arm Ltd. | Official Cross-Toolchain Package | `arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-linux-gnueabihf.tar.xz` | **13.3.rel1** (SHA256: `560267bdecf966b7a48467d0af6c81a85b906ef7b0a9b9dd91f506184b940281`) | Arm Developer Downloads | 2026-09-08 | Canonical cross-compiler package baseline | Canonical toolchain SHA |

---

## 2. Configuration & Build Contract

1. **Kernel Configuration Workflow**:
   - Baseline: `make ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabihf- multi_v7_defconfig`
   - Apply version-controlled fragment: `phase3_delta.config`
   - Update and validate: `make ARCH=arm olddefconfig`
   - Final effective config validation: Check presence of `CONFIG_ARCH_VIRT=y`, `CONFIG_VMSPLIT_3G=y`, `CONFIG_SERIAL_AMBA_PL011=y`, and `CONFIG_ARM_LPAE=n`.
2. **Heavyweight Build Isolation Contract**:
   - Full upstream kernel git tree (~1.5 GB) is NOT vendored into repository.
   - Default `make check` executes semantic validators, configuration audits, symbol lookup tests, and QEMU command contract checks without triggering multi-gigabyte external tree downloads.
