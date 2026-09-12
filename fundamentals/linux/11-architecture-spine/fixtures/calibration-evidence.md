# P3-M07 Calibration Evidence — Architecture Spine (Labs 7.1–7.3)

> Authoring/calibration runs performed on an **actual-host** WSL Ubuntu environment.
> This file records, per item, the exact command, the exact tool identity, the
> verbatim result, what it proves, what it does NOT prove, and its evidence status.
> Status vocabulary is exactly `VERIFIED` / `PARTIALLY VERIFIED` / `UNVERIFIED`.
>
> **PRIMARY runtime evidence is now the CANONICAL Linux 6.18.50 guest boot (§5).**
> An earlier boot on Ubuntu 6.8.0-134-generic is retained only as a comparison (§6).

## 0. Environment identity (actual-host vs canonical)

| Component | Actual-host used | Canonical baseline | Match? |
|---|---|---|---|
| Compiler | `arm-linux-gnueabihf-gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0` | Arm GNU Toolchain 13.3.rel1 `arm-none-linux-gnueabihf-` | **NO** (alternate host toolchain) |
| Binutils | GNU objdump/readelf/nm 2.42 (Ubuntu) | (toolchain binutils) | n/a |
| QEMU (system) | `qemu-system-arm 8.2.2 (Debian 1:8.2.2+ds-0ubuntu1.18)` | QEMU 11.1.1 | **NO** (actual-host) |
| QEMU (user) | `qemu-arm 8.2.2` (installed via apt `qemu-user`) | — | n/a |
| Kernel (canonical boot) | Linux **6.18.50**, pinned `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7`, built locally | Linux 6.18.50 `v6.18.50` | **YES** (version/commit; toolchain still actual-host) |
| Kernel (comparison boot) | Linux `6.8.0-134-generic` (Ubuntu 6.8.0-134.134-generic 6.8.12) | — | NO (non-canonical) |
| WSL host | x86_64, WSL2 kernel 6.18.33.2-microsoft-standard-WSL2 | — | n/a |
| strace | **UNAVAILABLE** (not installed) | — | n/a |

### 0.1 Descriptor model across the two captured kernels

| Capture | Boot-log `cr=` | SCTLR.TRE (bit28) | SCTLR.AFE (bit29) | Descriptor model |
|---|---|---|---|---|
| Ubuntu 6.8.0-134 (comparison) | `0x30c5387d` | 1 | **1** | LPAE-consistent (long-descriptor) |
| **Canonical 6.18.50 (primary)** | `0x10c5387d` | 1 | **0** | **non-LPAE short-descriptor (VERIFIED)** |

`cr=` is emitted by `arch/arm/kernel/setup.c:721` via `get_cr()` (live SCTLR read,
`mrc p15,0,r0,c1,c0,0`), AFTER `__v7_setup` applies its `crval`. In the pinned
6.18.50 tree:
- non-LPAE path, `arch/arm/mm/proc-v7-2level.S:164`:
  `crval clear=0x2120c302, mmuset=0x10c03c7d, ucset=0x00c01c7c`
  → `clear` sets bit29 (AFE), `mmuset` leaves it clear ⇒ `__v7_setup` CLEARS AFE ⇒ AFE=0.
- LPAE path, `arch/arm/mm/proc-v7-3level.S:148`:
  `crval clear=0x0122c302, mmuset=0x30c03c7d, ucset=0x00c01c7c`
  → `mmuset` sets bit29 ⇒ AFE stays 1.
- Selection: `arch/arm/mm/proc-v7.S:23` (includes `proc-v7-3level.S` under LPAE)
  vs `:25` (includes `proc-v7-2level.S` otherwise).

The **canonical** kernel shows `cr=0x10c5387d` ⇒ TRE=1, **AFE=0**, exactly the
non-LPAE prediction, and its built config carries `# CONFIG_ARM_LPAE is not set`.
This **confirms** the ARMv7 short-descriptor (non-LPAE) model that P3-M07 teaches.
The **Ubuntu** kernel shows `cr=0x30c5387d` ⇒ AFE=1, consistent ONLY with LPAE;
it is a different, non-canonical kernel and is kept as a comparison with the
"UNKNOWN / suggests LPAE" label.

---

## 1. Lab source compile/link

**Command:**
```bash
cd /mnt/g/ai_project/research/emb/fundamentals/linux/11-architecture-spine
arm-linux-gnueabihf-gcc -static -march=armv7-a -mfpu=vfpv4-d16 -mfloat-abi=hard -marm -O0 -g \
  -o build/calibration/addrspace.elf labs/07.1-proc-address-space/src/addrspace.c
arm-linux-gnueabihf-gcc -static -march=armv7-a -mfpu=vfpv4-d16 -mfloat-abi=hard -marm -O0 -g \
  -o build/calibration/svc_getpid.elf \
  labs/07.2-svc-syscall-trace/src/svc_main.c labs/07.2-svc-syscall-trace/src/svc_getpid.S \
  -Ilabs/07.2-svc-syscall-trace/src
arm-linux-gnueabihf-gcc -static -march=armv7-a -mfpu=vfpv4-d16 -mfloat-abi=hard -marm -O0 -g \
  -o build/calibration/kfault.elf labs/07.3-kernel-boundary-fault/src/kfault.c
```

**Result (verbatim):** all three link with exit 0. `file` reports for each:
`ELF 32-bit LSB executable, ARM, EABI5 version 1 (GNU/Linux), statically linked, ...`

**Proves:** the three committed sources compile and link into static ARM EABI
executables on the actual-host toolchain.

**Does NOT prove:** behaviour on the canonical Arm GNU Toolchain 13.3.rel1; any
runtime behaviour.

**Status: VERIFIED** (actual-host compile/link).

### 1.1 Build-flag finding (correction required)
The README build command `-march=armv7-a` **alone** fails on this hard-float
toolchain: `cc1: error: '-mfloat-abi=hard': selected architecture lacks an FPU`.
The working command adds `-mfpu=vfpv4-d16 -mfloat-abi=hard`. See §8.

---

## 2. SVC artifact static proof (readelf + objdump)

**Commands:**
```bash
arm-linux-gnueabihf-readelf -h build/calibration/svc_getpid.elf
arm-linux-gnueabihf-readelf -A build/calibration/svc_getpid.elf
arm-linux-gnueabihf-objdump -d build/calibration/svc_getpid.elf
```

**Result (verbatim key lines):**
```
  Machine:                           ARM
  Flags:                             0x5000400, Version5 EABI, hard-float ABI
  Tag_CPU_arch: v7
  Tag_FP_arch: VFPv4-D16
  Tag_ABI_VFP_args: VFP registers

000104e0 <svc_getpid_raw>:
   104e0:	e3a07014 	mov	r7, #20
   104e4:	ef000000 	svc	0x00000000
   104e8:	e12fff1e 	bx	lr
```

**Proves:** the ELF is ARM EABI5 hard-float; `svc_getpid_raw` contains
`mov r7,#20` (EABI `__NR_getpid=20`) immediately before `svc 0x00000000`, in ARM
mode (encodings 0xe3a07014/0xef000000/0xe12fff1e), in `.text`, in a symbol that
is actually called by `main` (`bl 104e0 <svc_getpid_raw>`).

**Does NOT prove:** that the `svc` actually trapped and returned at runtime.

**Status: VERIFIED** (static ELF/disassembly contract).

---

## 3. Validator behaviour on the real artifact

**Commands:**
```bash
arm-linux-gnueabihf-objdump -d build/calibration/svc_getpid.elf > build/calibration/svc_getpid.disasm
python3 scripts/check_svc_artifact.py --elf build/calibration/svc_getpid.elf \
  --disasm build/calibration/svc_getpid.disasm --entry-symbol svc_getpid_raw
```

**Result:** `[PASS] ELF machine is ARM (e_machine=40)` + `=== SVC ARTIFACT CONTRACT: PASS ===`, exit 0.

**Proves:** `check_svc_artifact.py` accepts the genuine real artifact (no script
fix was required).

**Does NOT prove:** runtime behaviour.

**Status: VERIFIED.**

### 3.1 Decoy regression (checker still rejects decoys)
Ran the checker against the pre-existing reviewer mutation artifacts; results:
`svc-x86.disasm` → REJECT (x86 `syscall`); `svc-decoy-comment.disasm` → REJECT
(comment only); `svc-debugonly.disasm` → REJECT (`.comment` section only);
`x86_64.elf` → REJECT (e_machine=62); `notelf.bin` → ERROR (bad magic);
`svc-deadbranch.disasm --entry-symbol svc_getpid_raw` → REJECT (dead branch);
missing disasm file → ERROR exit 2. **Status: VERIFIED** (no regression).

---

## 4. SVC runtime under qemu-arm user-mode (actual-host)

**Command:**
```bash
qemu-arm build/calibration/svc_getpid.elf
```

**Result (verbatim):**
```
raw svc getpid : 37419
libc getpid    : 37419
match          : yes
```
(pid value varies per run; the equality is the stable fact.)

**Proves:** the ARM `mov r7,#20; svc #0` sequence actually executes and returns a
real pid equal to libc `getpid()` — under qemu-arm user-mode emulation on the
host x86-64 kernel.

**Does NOT prove:** that the `svc` trapped into an *ARM* Linux kernel's
`vector_swi`/`sys_call_table` path (qemu-arm translates the ARM syscall to a host
x86-64 syscall).

**Status: VERIFIED** (real ARM user-space execution via actual-host QEMU).

---

## 5. CANONICAL Linux 6.18.50 guest boot (PRIMARY runtime evidence)

**Commands:**
```bash
Z=/opt/pins/linux-6.18.50/arch/arm/boot/zImage   # 11817472 B
I=fundamentals/linux/11-architecture-spine/build/calibration/initramfs.cpio.gz
qemu-system-arm -machine virt,highmem=off,gic-version=2 -cpu cortex-a7 -m 512M -smp 1 \
  -nographic -no-reboot -kernel "$Z" -initrd "$I" \
  -append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init panic=1"
```

**Artifact identity:**
- zImage sha256: `46e75c3d23ef46091e2d6ea86b4a0e1c96d7ae343b9898d538beb20ecf57f0b0`
- Kernel: Linux 6.18.50, pinned commit `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7`,
  built locally from `multi_v7_defconfig` +
  `fundamentals/linux/06-kernel-build-boot/fixtures/configs/phase3_delta.config`
  (effective `# CONFIG_ARM_LPAE is not set`, `CONFIG_VMSPLIT_3G=y`).
- Toolchain: actual-host `arm-linux-gnueabihf-gcc 13.3.0` (NOT canonical Arm GNU 13.3.rel1).
- QEMU: actual-host `qemu-system-arm 8.2.2` (NOT canonical 11.1.1).
- Full log: `build/canonical/boot.log` (261 lines).

**Result (verbatim key lines):**
```
Linux version 6.18.50 (root@ZHR) (arm-linux-gnueabihf-gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0, GNU ld (GNU Binutils for Ubuntu) 2.42) #1 SMP ...
CPU: ARMv7 Processor [410fc075] revision 5 (ARMv7), cr=10c5387d
Memory: 421160K/524288K available (16384K kernel code, 2551K rwdata, 7080K rodata, 2048K init, 391K bss, 36004K reserved, 65536K cma-reserved, 0K highmem)
Kernel command line: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init panic=1
...
Run /init as init process
M07-INIT-GETPID=0x00000001
M07-INIT-MKDIR-PROC=0x00000000
M07-INIT-MKDIR-SYS=0x00000000
M07-INIT-MOUNT-PROC=0x00000000
M07-INIT-MOUNT-SYS=0x00000000
M07-RUN-SVC-BEGIN
raw svc getpid : 46
libc getpid    : 46
match          : yes
M07-RUN-SVC-END rc=0x00000000
M07-RUN-KFAULT-BEGIN
pid=47 attempting controlled read of 0xc0008000 (>= PAGE_OFFSET 0xC0000000)
caught SIGSEGV: userspace fault on kernel-range access (EXPECTED)
proves: PL0 cannot dereference kernel half; does NOT prove any physical mapping
M07-RUN-KFAULT-END rc=0x00002a00
M07-INIT-END
[    8.022901] reboot: Power down
```

**Proves:** the CANONICAL Linux 6.18.50 kernel boots on Cortex-A7 under actual-host
QEMU; a freestanding no-libc init mounts procfs/sysfs via raw EABI `svc #0`
(mount=21, mkdir=39); raw `svc #0` `__NR_getpid=20` returns a matching pid for the
`svc_getpid.elf` child; `kfault.elf` dereferencing `0xC0008000` delivers SIGSEGV and
exits 42 (`rc=0x2a00 == 42<<8`).

**Does NOT prove:** canonical QEMU 11.1.1 runtime (actual-host 8.2.2 was used);
canonical Arm GNU Toolchain 13.3.rel1 build; physical hardware.

**Status: VERIFIED** (canonical kernel guest boot; canonical QEMU 11.1.1 runtime UNVERIFIED).

### 5.1 SCTLR descriptor-model probe, canonical kernel (cr=0x10c5387d)

`cr=0x10c5387d` ⇒ TRE(bit28)=1, **AFE(bit29)=0**. This is exactly the non-LPAE
`v7_crval` post-alignment result (`proc-v7-2level.S:164`: `clear=0x2120c302` sets
bit29, `mmuset=0x10c03c7d` leaves it clear ⇒ AFE cleared). Combined with the built
`# CONFIG_ARM_LPAE is not set`, this **VERIFIES the ARMv7 short-descriptor
(non-LPAE) model** for the canonical boot, in contrast to the Ubuntu kernel's
AFE=1 (§6). **Status: VERIFIED.**

---

## 6. Non-canonical Ubuntu kernel boot (comparison only)

An earlier boot on Ubuntu `6.8.0-134-generic` (a DIFFERENT, non-canonical kernel)
was captured before the canonical 6.18.50 build existed. It is retained here only
as the comparison that motivated the LPAE concern, and keeps its honest label.

**Result (verbatim key lines):**
```
Linux version 6.8.0-134-generic (buildd@bos03-arm64-064) (arm-linux-gnueabihf-gcc-13 (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0, ...) ...
CPU: ARMv7 Processor [410fc075] revision 5 (ARMv7), cr=30c5387d
Memory: 451352K/524288K available (... 0K highmem)
...
raw svc getpid : 70
libc getpid    : 70
match          : yes
...
pid=71 attempting controlled read of 0xc0008000 ...
caught SIGSEGV: userspace fault on kernel-range access (EXPECTED)
...
reboot: Power down
```

`cr=0x30c5387d` ⇒ TRE=1, **AFE=1** ⇒ consistent ONLY with the LPAE crval
(`proc-v7-3level.S:148`), NOT the frozen non-LPAE model. **Descriptor model:
UNKNOWN / suggests LPAE** (no embedded `.config` to close it). The genuine userspace
wins from this boot (real SVC trap, real SIGSEGV, real maps format) remain valid
but are superseded as primary evidence by §5.

**Status: PARTIALLY VERIFIED** (real ARM guest boot; descriptor model non-canonical).

---

## 7. Address-space maps (canonical kernel, Lab 7.1)

**Result (verbatim, from the canonical boot in §5):**
```
pid            : 45
func   .text  : 0x10440
global data   : 0x62230
global bss    : 0x63014
heap  malloc  : 0x66da0
stack local   : 0xbedc4b90
...
00010000-0005f000 r-xp ... /addrspace.elf
0005f000-00062000 r--p ... /addrspace.elf
00062000-00063000 rw-p ... /addrspace.elf
00063000-00066000 rw-p
00066000-00088000 rw-p ... [heap]
beda4000-bedc5000 rw-p ... [stack]
bede1000-bede2000 r-xp ... [sigpage]
bede2000-bede6000 r--p ... [vvar]
bede6000-bede7000 r-xp ... [vdso]
ffff0000-ffff1000 r-xp ... [vectors]
```

**Proves:** each printed address falls in the correct maps region
(text→r-xp, data/bss→rw-p, heap→[heap], stack→[stack] just below 0xBF000000);
no `0xC0000000+` line appears (kernel half absent). The 3G/1G split
(`TASK_SIZE=0xBF000000`) is directly observed, consistent with `CONFIG_VMSPLIT_3G=y`.

**Does NOT prove:** physical addresses; the L1/L2 page-table *contents* (the maps
format is descriptor-model independent — the short-descriptor model is evidenced
separately by §5.1's `cr=10c5387d` + `CONFIG_ARM_LPAE=n`).

**Status: VERIFIED** (canonical-kernel maps capture; physical addresses UNVERIFIED).

---

## 8. Correction / fix log

| # | Symptom | Root cause | Fix | Regression |
|---|---|---|---|---|
| 1 | `-march=armv7-a` alone fails: `-mfloat-abi=hard: selected architecture lacks an FPU` | gnueabihf toolchain defaults to hard-float; armv7-a alone implies no FPU | add `-mfpu=vfpv4-d16 -mfloat-abi=hard` | all three labs link cleanly |
| 2 | `kfault.elf` SIGSEGV handler exits 42 but its two `printf` lines never appear when stdout is a pipe/file | `_exit(42)` skips stdio flush; QEMU `-nographic` captures a pipe | add `fflush(stdout)` before `_exit(42)` | "caught SIGSEGV" line now appears in the capture |
| 3 | kernel warns `process '/svc_getpid.elf' started with executable stack` | `svc_getpid.S` lacks `.note.GNU-stack` | append `.section .note.GNU-stack,"",%progbits` as the last directive | warning gone; `svc` path unchanged; checker still PASS |

---

## 9. Evidence summary table

| Dimension | Status | Basis | Does not prove |
|---|---|---|---|
| Source identity (repo files) | VERIFIED | read-back of committed sources | target runtime |
| Target compile/link (actual-host) | VERIFIED | arm-linux-gnueabihf-gcc 13.3.0 executed | canonical toolchain build |
| Static ELF/disassembly contract | VERIFIED | readelf/objdump capture | runtime |
| `check_svc_artifact.py` positive + decoys | VERIFIED | executed; decoys REJECT/ERROR | runtime |
| SVC runtime (qemu-arm user-mode) | VERIFIED | real getpid() == libc getpid() | ARM-kernel vector_swi path |
| **Canonical Linux 6.18.50 guest boot (actual-host QEMU 8.2.2)** | **VERIFIED** | zImage sha256 + boot log + Cortex-A7 + frozen bootargs | canonical QEMU 11.1.1 runtime; canonical toolchain |
| **SCTLR descriptor-model probe, canonical kernel (cr=0x10c5387d)** | **VERIFIED** | TRE=1, AFE=0 ⇒ non-LPAE short-descriptor (proc-v7-2level.S:164) + CONFIG_ARM_LPAE=n | L1/L2 table *contents* at runtime |
| **Real /proc/<pid>/maps on canonical kernel** | **VERIFIED** | captured maps; 3G/1G split observed | physical addresses; page-table contents |
| **Real SVC trap on canonical kernel (raw == libc getpid)** | **VERIFIED** | raw svc getpid==libc on 6.18.50 | per-instruction kernel register transitions |
| **Controlled kernel-range SIGSEGV on canonical kernel (F13)** | **VERIFIED** | SIGSEGV + exit 42 on 6.18.50 | physical mapping contents |
| Non-canonical Ubuntu 6.8.0-134 boot (comparison) | PARTIALLY VERIFIED | real guest boot; cr=0x30c5387d AFE=1 ⇒ LPAE-consistent | frozen CONFIG_ARM_LPAE=n |
| Canonical QEMU 11.1.1 appliance boot | UNVERIFIED | not executed (actual-host 8.2.2 used) | — |
| Canonical toolchain (arm-none-linux-gnueabihf 13.3.rel1) | UNVERIFIED | not executed (alternate host toolchain used) | — |
| Live GDB register observation | UNVERIFIED | not performed | — |
| strace observation | UNVERIFIED | strace unavailable on host | — |
| Physical hardware | UNVERIFIED | out of scope | — |

---

## 10. Reproducibility

All commands above were executed under WSL Ubuntu with the repo mounted at
`/mnt/g/ai_project/research/emb`. Full logs and binaries are retained under
`build/` (gitignored): `build/canonical/boot.log` (canonical 6.18.50 boot),
`build/calibration/` (`boot.log` for the Ubuntu comparison, `*.elf`,
`initramfs.cpio.gz`, `init.c`, `svc_getpid.disasm`). The canonical zImage is at
`/opt/pins/linux-6.18.50/arch/arm/boot/zImage`
(sha256 `46e75c3d23ef46091e2d6ea86b4a0e1c96d7ae343b9898d538beb20ecf57f0b0`).
The comparison armhf kernel was obtained by `dpkg --add-architecture armhf` + a
`ports.ubuntu.com` source, then `linux-image-6.8.0-134-generic` (13 MiB deb).
