# P3-M03 Source Ledger — Minimal Rootfs, BusyBox, Pseudo-Filesystems & PID 1 Init Lifecycle

> Checked: **2026-09-09**.  
> Primary BusyBox source baseline: **BusyBox 1.36.1** (tag `1_36_1`, lightweight tag commit `1a64f6a20aaf6ea4dbba68bbfa8cc1ab7e5c57c4`, released 2023-05-19; GPL-2.0-only).  
> Primary kernel source baseline: **Linux 6.18.50 LTS** (tag `v6.18.50`, peeled commit `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7`, released 2026-09-07; GPL-2.0-only).  
> Primary emulation baseline: **QEMU 11.1.1** (tag `v11.1.1`, peeled commit `c3d48b7d1e89604920e5b81b91140c2ad39a1943`, released 2026-08-26; GPL-2.0).  
> Canonical toolchain baseline: **Arm GNU Toolchain 13.3.rel1** (`arm-none-linux-gnueabihf-`, GCC 13.3.1 20240614, Binutils 2.42, Glibc 2.39).  
> Alternate host toolchain profile (distro environment): **Ubuntu 24.04 LTS `gcc-arm-linux-gnueabihf`** (`arm-linux-gnueabihf-`, GCC 13.3.0).

---

## 1. Upstream & Specification Traceability Table

| ID | Source / Artifact | Organization / Author | Type | Path / Exact Section | Version / Tag / Commit | Upstream URL / Origin | Checked Date | Teaching Purpose | Risk / Constraints |
|---|---|---|---|---|---|---|---|---|---|
| M03-S01 | BusyBox Multi-Call Binary | BusyBox Project / Erik Andersen, Denys Vlasenko et al. | Official Upstream Git | `applets/applets.c`, `libbb/appletlib.c` | **BusyBox 1.36.1** (tag `1_36_1`, commit `1a64f6a20aaf6ea4dbba68bbfa8cc1ab7e5c57c4`) | `https://git.busybox.net/busybox` / `https://github.com/mirror/busybox.git` | 2026-09-09 | Trace `argv[0]` applet dispatch and multi-call architecture | Canonical userspace binary |
| M03-S02 | BusyBox Init Implementation | BusyBox Project | Official Upstream Git | `init/init.c` | **BusyBox 1.36.1** (same commit) | `https://git.busybox.net/busybox` | 2026-09-09 | Trace `init_main()`, signal handling (`SIGCHLD`, `SIGTERM`), orphan zombie reaping (`waitpid(-1, NULL, WNOHANG)`), and `/etc/inittab` action parsing | Distinguish BusyBox init from shell PID 1 |
| M03-S03 | Linux Kernel Init Sequence | Linux Kernel Community | Official Upstream Git | `init/main.c` | **Linux 6.18.50 LTS** (tag `v6.18.50`, commit `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7`) | `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git` | 2026-09-09 | Trace `kernel_init()`, `try_to_run_init_process()`, candidate search list, and errno return behavior (-EACCES = 13, -ENOENT = 2) | Authoritative kernel-to-userspace contract |
| M03-S04 | Linux Ramfs/Rootfs Documentation | Linux Kernel Documentation | Upstream Documentation | `Documentation/filesystems/ramfs-rootfs-initramfs.rst` | **Linux 6.18.50 LTS** | `Documentation/filesystems/ramfs-rootfs-initramfs.rst` | 2026-09-09 | Distinguish `initramfs` (tmpfs archive unpacked by kernel) from legacy `initrd` and persistent rootfs | Authoritative filesystem model |
| M03-S05 | Filesystem Hierarchy Standard | Linux Foundation | Specification | FHS 3.0 (Sections 3.4–3.15: `/bin`, `/sbin`, `/etc`, `/dev`, `/proc`, `/sys`) | FHS 3.0 (2015-03-19) | `https://refspecs.linuxfoundation.org/FHS_3.0/` | 2026-09-09 | Define the minimal directory skeleton required for standard userspace | Pedagogical minimal subset |
| M03-S06 | QEMU System Emulator | QEMU Project | Official Upstream Git | `hw/arm/virt.c` | **QEMU 11.1.1** (tag `v11.1.1`, commit `c3d48b7d1e89604920e5b81b91140c2ad39a1943`) | `https://gitlab.com/qemu-project/qemu.git` | 2026-09-09 | Canonical launch contract `-machine virt,highmem=off,gic-version=2 -cpu cortex-a7 -m 512M -smp 1 -nographic` | Virtual machine contract |
| M03-S07 | Phase 3 Curriculum Design | This Repository | Canonical Curriculum Architecture | `research/phase-3/2026-09-08-embedded-linux-curriculum-design.md` | Commit `200c46f69c1664cd28784573148add0f637c4f9a` | `roadmap/phase-3-embedded-linux.md` | 2026-09-09 | Module budget 4.0 h MUST, labs 3.1–3.6, faults F07–F09 | Repository canonical |
| M03-S08 | Arm GNU Toolchain | Arm Ltd. | Official Cross-Toolchain Package | `arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-linux-gnueabihf.tar.xz` | **13.3.rel1** (SHA256: `560267bdecf966b7a48467d0af6c81a85b906ef7b0a9b9dd91f506184b940281`) | Arm Developer Downloads | 2026-09-09 | Canonical cross-compiler package baseline | Canonical toolchain SHA |

---

## 2. Configuration & Build Contract

1. **BusyBox Configuration Baseline**:
   - Start from `make defconfig`.
   - Enable `CONFIG_STATIC=y` (produces static ARM ELF without dynamic loader requirement).
   - Disable `CONFIG_TC=n` (eliminates dependency on obsolete CBQ scheduler headers dropped in modern Linux headers).
   - Install applets into staging directory using `make install CONFIG_PREFIX=<staging_dir>`.
2. **Deterministic Rootfs / Initramfs Contract**:
   - Packaging tool: hermetic `scripts/pycpio.py` (`newc`) when a `devnodes.manifest` is present (mandatory for device nodes: host `cpio` cannot encode char/block entries without root-owned `mknod`); otherwise standard GNU/POSIX `cpio -H newc` or the `pycpio.py` fallback.
   - Archive entries sorted deterministically; directory and file permissions normalized; UID/GID fixed to 0; timestamps fixed.
   - Canonical static nodes: `dev/console` (char 5:1, 0600), `dev/null` (char 1:3, 0666), validated from CPIO metadata by `scripts/verify_initramfs_nodes.sh`.
   - `/init` or `/sbin/init` must possess executable permission (`0755`).
   - Pseudo-filesystem mount points (`/proc`, `/sys`, `/dev`) must be created as empty directory mount points; `CONFIG_DEVTMPFS_MOUNT=y` does NOT automount devtmpfs on initramfs boot, so userspace mounts it manually.
3. **Synthetic vs Real Evidence Contract**:
   - `fixtures/src/synthetic_multicall.c` builds `SYNTHETIC PEDAGOGICAL FIXTURE — NOT BUSYBOX` (`synthetic_rootfs.cpio.gz`) for fast static/component teaching only.
   - Real runtime evidence always comes from `scripts/stage_real_rootfs.sh` + `package_initramfs.sh` over the real BusyBox 1.36.1 staging (`real_rootfs.cpio.gz`) and is gated by `run_real_qemu_m03.sh` (real ash/ps/mount markers; synthetic strings rejected).
4. **Scored Assessment Real-BusyBox Contract (Round 2)**:
   - Scored M03 Challenge/Gate candidates are REAL BusyBox trees: `scripts/provision_real_busybox_tree.sh` installs the verified `bin/busybox` artifact and its genuine applet symlinks from the real build staging; the reviewer fixture generators derive both the reference and the opaque defective fixture from that same lane. The synthetic multicall is never scored material.
   - `scripts/validate_real_busybox.sh` enforces artifact identity (static ARM ELF, `BusyBox v1.36.1` identity string, upstream multi-call banner, applet-table coverage, applet entries resolving to `bin/busybox`, `/sbin/init` wiring, active `/init` mounts, and staging-vs-packaged-archive equivalence including modes, symlink targets and contents).
   - The scored production boot path is `rdinit=/sbin/init` (real BusyBox init consuming `/etc/inittab`); `/init` (the Lab 3.4 shell-script PID 1 for `rdinit=/init`) remains part of the tree contract but is not the scored production init path.
   - `scripts/run_real_busybox_candidate.sh` boots ONLY the submitted packaged archive against the pinned Linux 6.18.50 `zImage` and records archive-bound provenance (archive/kernel digests plus the pinned invocation). `scripts/verify_busybox_candidate_runtime.sh` requires real BusyBox as PID 1, the submitted `rcS` executed via the submitted inittab `::sysinit` line, the `askfirst` console handoff, active proc/sysfs/devtmpfs mounts, a real BusyBox process table, and a live interactive shell; synthetic strings and evidence captured for a different archive are rejected.
   - Reviewer Gate grading performs static grading of the repaired tree plus a FRESH boot of the learner's packaged archive: a canonical/stock rootfs is never booted in place of a submission.
5. **Heavyweight Build Isolation Contract**:
   - Default `make check` executes deterministic semantic validators, ELF header audits, directory permission checks, and synthetic QEMU launch validations without forcing heavyweight external source downloads.
   - Opt-in targets `real-busybox-build-check` and `real-qemu-check` test actual compiled binaries and QEMU boots.
