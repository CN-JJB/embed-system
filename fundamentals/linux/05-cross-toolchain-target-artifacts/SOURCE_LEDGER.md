# P3-M01 Source Ledger — Toolchains & Target Artifacts

> Checked: **2026-09-08**.  
> Primary toolchain baseline: **Arm GNU Toolchain 13.3.rel1** (`arm-none-linux-gnueabihf-`).  
> Alternate host distro profile: **Ubuntu 24.04 LTS `gcc-arm-linux-gnueabihf`** (`arm-linux-gnueabihf-`).  
> Reference kernel source: **Linux 6.18.50 LTS** (commit `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7`).

---

## 1. Upstream & Specification Traceability Table

| ID | Source / Artifact | Organization / Author | Type | Path / Exact Section | Version / Tag / Commit | Upstream URL / Origin | Checked Date | Teaching Purpose | Risk / Constraints |
|---|---|---|---|---|---|---|---|---|---|
| M01-S01 | Arm GNU Toolchain | Arm Ltd. | Official Cross-Toolchain Release | `bin/arm-none-linux-gnueabihf-gcc`, `arm-none-linux-gnueabihf/libc/` | **13.3.rel1** (GCC 13.3.1 20240614, Binutils 2.42, Glibc 2.39) | Package: `arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-linux-gnueabihf.tar.xz` SHA256: `560267bdecf966b7a48467d0af6c81a85b906ef7b0a9b9dd91f506184b940281` | 2026-09-08 | Canonical toolchain target tuple & official sysroot baseline | High; canonical MUST commands require this prefix |
| M01-S02 | Ubuntu Distro Cross-Toolchain | Canonical Ltd. / Debian | Distro Cross-Compiler Package | `/usr/bin/arm-linux-gnueabihf-gcc`, `/usr/arm-linux-gnueabihf/` | **Ubuntu 24.04 LTS (noble)** package `gcc-arm-linux-gnueabihf` (13.3.0-6ubuntu2~24.04.1) | Distro repository `https://mirrors.tuna.tsinghua.edu.cn/ubuntu` | 2026-09-08 | Alternate host profile for environment without standalone toolchain | Low–Medium; target tuple omits `none` |
| M01-S03 | `ld.so(8)` | Linux man-pages project | Official Manual | Dynamic Linker / Interpreter Contract | **man-pages 6.18** | `https://man7.org/linux/man-pages/man8/ld.so.8.html` | 2026-09-08 | Explains `PT_INTERP`, shared library search order, `DT_RUNPATH`, `/etc/ld.so.cache` | Low; stable interface |
| M01-S04 | `elf(5)` | Linux man-pages project | Official Specification Reference | ELF Header & Program Header Formats | **man-pages 6.18** | `https://man7.org/linux/man-pages/man5/elf.5.html` | 2026-09-08 | Detailed definition of `Elf32_Ehdr`, `Elf32_Phdr`, `PT_INTERP`, `PT_DYNAMIC` | Low; POSIX/SysV ELF standard |
| M01-S05 | `readelf(1)` | GNU Binutils Project | Official Tool Manual | Options `-h`, `-l`, `-d`, `-s` | **Binutils 2.42** | `https://sourceware.org/binutils/docs/binutils/readelf.html` | 2026-09-08 | Authoritative tool for inspecting ELF machine, segment types, and dynamic tags | Low |
| M01-S06 | Linux Kernel ELF Loader | Linux Kernel Community | Upstream Kernel Source | `fs/binfmt_elf.c` | **Linux 6.18.50 LTS** (commit `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7`) | `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git` | 2026-09-08 | Explains kernel handling of `PT_INTERP` and why missing interpreter returns `-ENOENT` | Authoritative |
| M01-S07 | Phase 3 Curriculum Design | This Repository | Canonical Architecture Plan | `research/phase-3/2026-09-08-embedded-linux-curriculum-design.md` | Commit `200c46f69c1664cd28784573148add0f637c4f9a` | `roadmap/phase-3-embedded-linux.md` | 2026-09-08 | Canonical 3.5 h MUST budget, F01/F02 faults, gate requirements | Repository canonical |

---

## 2. Toolchain Profile Separation Contract

1. **Canonical Profile (`arm-none-linux-gnueabihf-`)**:
   - All MUST scripts, Makefiles, and student documentation default to `CROSS_COMPILE ?= arm-none-linux-gnueabihf-`.
   - Toolchain sysroot points to the glibc multiarch sysroot containing `/lib/ld-linux-armhf.so.3` and `/usr/lib/libc.so.6`.
2. **Alternate Distro Profile (`arm-linux-gnueabihf-`)**:
   - Never selected automatically. It is an explicit authoring/calibration profile and must be requested with `CROSS_COMPILE=arm-linux-gnueabihf-`.
   - Its actual compiler/binutils/sysroot identity must be reported separately from the canonical Arm GNU Toolchain profile.
   - It targets the same broad ARM GNU/Linux hard-float ABI family, but artifact/runtime parity with the canonical Arm package is not assumed without verification.
