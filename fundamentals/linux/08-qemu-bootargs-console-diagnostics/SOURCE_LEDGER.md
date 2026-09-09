# P3-M04 Source Ledger — QEMU Bring-Up, Bootargs, Console Handoff & Boot Failure Diagnostics

> Checked: **2026-09-09**.  
> Primary kernel source baseline: **Linux 6.18.50 LTS** (tag `v6.18.50`, peeled commit `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7`, released 2026-09-07; GPL-2.0-only).  
> Primary emulation baseline: **QEMU 11.1.1** (tag `v11.1.1`, peeled commit `c3d48b7d1e89604920e5b81b91140c2ad39a1943`, released 2026-08-26; GPL-2.0).  
> Canonical toolchain baseline: **Arm GNU Toolchain 13.3.rel1** (`arm-none-linux-gnueabihf-`, GCC 13.3.1 20240614, Binutils 2.42, Glibc 2.39).  
> Alternate host toolchain profile (distro environment): **Ubuntu 24.04 LTS `gcc-arm-linux-gnueabihf`** (`arm-linux-gnueabihf-`, GCC 13.3.0).

---

## 1. Upstream & Specification Traceability Table

| ID | Source / Artifact | Organization / Author | Type | Path / Exact Section | Version / Tag / Commit | Upstream URL / Origin | Checked Date | Teaching Purpose | Risk / Constraints |
|---|---|---|---|---|---|---|---|---|---|
| M04-S01 | Linux Kernel Parameters Documentation | Linux Kernel Community | Official Documentation | `Documentation/admin-guide/kernel-parameters.rst` | **Linux 6.18.50 LTS** (tag `v6.18.50`, commit `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7`) | `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git` | 2026-09-09 | Trace `console=`, `earlycon=`, `rdinit=`, `root=`, `mem=` | Authoritative parameter definitions |
| M04-S02 | Linux Serial Console Documentation | Linux Kernel Community | Official Documentation | `Documentation/admin-guide/serial-console.rst` | **Linux 6.18.50 LTS** (same commit) | `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git` | 2026-09-09 | Console registration, multiple console ordering, `/dev/console` handoff | Core console mechanism |
| M04-S03 | Earlycon Driver Implementation | Linux Kernel Community | Official Upstream Git | `drivers/tty/serial/earlycon.c` | **Linux 6.18.50 LTS** (same commit) | `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git` | 2026-09-09 | Trace early polled-MMIO character write loop before driver registration | Explains why earlycon survives before driver init |
| M04-S04 | ARM PL011 UART Driver | Linux Kernel Community | Official Upstream Git | `drivers/tty/serial/amba-pl011.c` | **Linux 6.18.50 LTS** (same commit) | `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git` | 2026-09-09 | Trace PL011 MMIO base (`0x09000000`), IRQ 1, console registration | Hardware model reference |
| M04-S05 | QEMU System Emulator Model | QEMU Project | Official Upstream Git | `docs/system/arm/virt.rst`, `hw/arm/virt.c` | **QEMU 11.1.1** (tag `v11.1.1`, commit `c3d48b7d1e89604920e5b81b91140c2ad39a1943`) | `https://gitlab.com/qemu-project/qemu.git` | 2026-09-09 | Canonical launch contract `-machine virt,highmem=off,gic-version=2 -cpu cortex-a7 -m 512M -smp 1 -nographic` | Non-LPAE memory map constraint |
| M04-S06 | Phase 3 Curriculum Design | This Repository | Canonical Curriculum Architecture | `research/phase-3/2026-09-08-embedded-linux-curriculum-design.md` | Commit `200c46f69c1664cd28784573148add0f637c4f9a` | `roadmap/phase-3-embedded-linux.md` | 2026-09-09 | Module budget 3.5 h MUST, labs 4.1–4.3, faults F04–F06 | Repository canonical |
| M04-S07 | Arm GNU Toolchain | Arm Ltd. | Official Cross-Toolchain Package | `arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-linux-gnueabihf.tar.xz` | **13.3.rel1** (SHA256: `560267bdecf966b7a48467d0af6c81a85b906ef7b0a9b9dd91f506184b940281`) | Arm Developer Downloads | 2026-09-09 | Canonical cross-compiler package baseline | Canonical toolchain SHA |

---

## 2. Canonical Platform Launch Contract

To ensure 100% deterministic bring-up and reproducible diagnostics across environments:

```text
qemu-system-arm \
  -machine virt,highmem=off,gic-version=2 \
  -cpu cortex-a7 \
  -m 512M \
  -smp 1 \
  -nographic \
  -kernel <zImage> \
  -initrd <rootfs.cpio.gz> \
  -append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init"
```

### Key Contract Guarantees:
1. **Machine**: `virt,highmem=off,gic-version=2` restricts memory and MMIO devices to the 32-bit physical address space, preventing virtual address mapping failures on non-LPAE kernels (`CONFIG_ARM_LPAE=n`).
2. **CPU**: Explicit `cortex-a7` prevents QEMU from defaulting to `cortex-a15`.
3. **Memory**: Explicit `512M` ensures consistent memory layout starting at physical DRAM base `0x40000000`.
4. **Bootargs** (exactly one `console=` token; repeated `console=` lines are rejected — real Linux resolves same-type repeats first-of-type, not last-wins):
   - `earlycon=pl011,0x09000000`: Directs polled early printk output to the PL011 UART register from the very first instruction.
   - `console=ttyAMA0,115200`: Registers the primary interrupt-driven character console once serial subsystem initializes.
   - `rdinit=/init`: Designates `/init` as the initial userspace program in the unpacked initramfs.

### Evidence Contracts:
- **Static teaching fixture**: `fixtures/reference_boot.log` (real BusyBox capture) is audited by `scripts/audit_boot_milestones.sh` for ordered-milestone log-analysis practice only; forged text passes it by design.
- **Runtime certification**: `scripts/verify_runtime_boot.sh` binds a log to an actual execution (command line, version, console handoff pair, initramfs unpack, init, real BusyBox identity/ps/mounts) and rejects forged, truncated, or mismatched logs. The M04 reviewer oracle re-executes the candidate launch and verifies the fresh capture.
