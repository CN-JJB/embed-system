# P3-M01 — Cross-Compilation Toolchains, Target Tuples, Sysroots & Target Artifacts

> **Phase 3 / Module 01**  
> **Target Depth:** L3 Toolchain Architecture / L4-Local Binary Artifact Fault Diagnosis  
> **Prerequisites:** P1-M03 (Compilation, Linker, ELF Sections & Symbols), P1-M04 (Process Lifecycle & `execve`)  
> **Planned Learner Time:** **3.5 h MUST**, 1.0 h SHOULD  
> **AI Mode:** AI-Free first attempt on Challenge and Gate; official GNU Binutils manuals and Linux man-pages permitted.

---

## 1. Why Cross-Compilation Toolchains Matter

In Phase 1, you built software on the **host machine** (x86-64) for execution on the same host machine. In Phase 2, you used `arm-none-eabi-gcc` to produce bare-metal ELF and raw binary firmware for Cortex-M microcontrollers without an operating system.

In Embedded Linux, software execution spans two completely different worlds:
1. The **Host System** (e.g. x86-64 Linux build machine / workstation) where compilers, linkers, and build systems run;
2. The **Target System** (e.g. 32-bit ARMv7-A Cortex-A7 virtual or physical board) running the Linux kernel, dynamic linker, C runtime library, and userspace applications.

When a binary compiled on the host fails on the target, developers frequently encounter confusing errors:
- Executing `./app` produces `cannot execute binary file: Exec format error`
- Executing `./app` produces `sh: ./app: No such file or directory` or `not found`, even when `ls -l ./app` proves the file exists!

These failures are not mysterious; they are strict violations of the **target Application Binary Interface (ABI)**, the **ELF machine contract**, or the **dynamic linker search contract**. Mastering the toolchain tuple, the sysroot, program headers (`PT_INTERP`), dynamic sections (`DT_NEEDED`), and the differences between static and dynamic linking is the first mandatory foundation of Embedded Linux engineering.

---

## 2. Mental Model

### 2.1 The Cross-Compilation Axis

```text
+-------------------------------------------------------------------------------+
| HOST (x86-64 Linux)                                                           |
|                                                                               |
|   source.c  --->  arm-none-linux-gnueabihf-gcc  --->  ELF32 ARM Target Binary |
|                                ^                                              |
|                                |                                              |
|                          Target Sysroot                                       |
|                   (/usr/include, /lib, /usr/lib)                              |
+-------------------------------------------------------------------------------+
                                      |
                                      | Deploy to Target (NFS, SCP, initramfs)
                                      v
+-------------------------------------------------------------------------------+
| TARGET (ARMv7-A Cortex-A7 Linux Kernel + Rootfs)                              |
|                                                                               |
|   1. Shell executes execve("./app")                                           |
|   2. Kernel inspects ELF header:                                              |
|      - Is Machine == EM_ARM (40)?                                             |
|        No  --> returns -ENOEXEC ("Exec format error")                         |
|      - Is PT_INTERP segment present?                                          |
|        Yes --> opens dynamic loader path (e.g. /lib/ld-linux-armhf.so.3)      |
|                Does loader exist in rootfs?                                   |
|                No  --> returns -ENOENT ("No such file or directory")          |
|                Yes --> maps loader, loads DT_NEEDED shared libraries,         |
|                        resolves relocations, and jumps to app entry           |
|        No  --> static binary: kernel maps segments directly and jumps         |
+-------------------------------------------------------------------------------+
```

### 2.2 Target Tuple Anatomy

Every cross-toolchain binary is prefixed by a canonical **target tuple** defining its architecture, vendor, operating system, and ABI:

$$\text{Target Tuple} = [\text{arch}]-[\text{vendor}]-[\text{os}]-[\text{abi}]$$

| Component | Canonical Package Value | Meaning / Architecture Contract | Alternate Distro Value |
|---|---|---|---|
| `[arch]` | `arm` | 32-bit ARM instruction set architecture (ARMv7-A) | `arm` |
| `[vendor]` | `none` | Independent / generic vendor (unbound to OEM) | (omitted) |
| `[os]` | `linux` | Linux kernel system call interface (`sys_call_table`, EABI `svc #0`) | `linux` |
| `[abi]` | `gnueabihf` | GNU C Library (glibc), EABI calling convention, **Hard-Float** hardware VFP/NEON | `gnueabihf` |

#### Comparative Triples:
- **`arm-none-linux-gnueabihf-`** (Canonical Phase 3 baseline): Targets ARMv7-A Linux with GNU glibc and hardware floating point (`-mfloat-abi=hard -mfpu=vfpv4`).
- **`arm-linux-gnueabihf-`** (Ubuntu/Debian host package): Functionally identical ABI target for distro-managed development.
- **`arm-none-eabi-`** (Phase 2 MCU baseline): Targets bare-metal microcontrollers (Cortex-M) with Newlib libc, without an OS (`-mthumb -mcpu=cortex-m3`).
- **`arm-linux-musleabihf-`**: Targets ARM Linux with the lightweight `musl` C library rather than glibc. Dynamically linked binaries request `/lib/ld-musl-armhf.so.1`.

---

## 3. Minimal Theory Boundary

### 3.1 ELF Machine Identity (`readelf -h`)
The Linux kernel ELF loader (`fs/binfmt_elf.c`) reads the 52-byte ELF32 header. It checks:
- `e_ident[EI_MAG0..3]`: Must be `\x7fELF`.
- `e_ident[EI_CLASS]`: Must match target pointer size (`ELF32` vs `ELF64`).
- `e_ident[EI_DATA]`: Endianness (`2's complement, little endian` for standard ARM).
- `e_machine`: Architecture code. For 32-bit ARM, this MUST be `EM_ARM` (decimal 40, hex `0x28`). If the binary was built with the host compiler, it has `EM_X86_64` (decimal 62, hex `0x3E`), and the target kernel immediately rejects it with `-ENOEXEC` (`Exec format error`).
- `e_flags`: ABI flags. Canonical ARM hard-float binaries show `Flags: 0x5000400, Version5 EABI, hard-float ABI`.

### 3.2 Dynamic Linking Headers: `PT_INTERP` and `DT_NEEDED`
When GCC links a dynamic binary:
1. It creates a program header segment of type `PT_INTERP` (Segment Type `INTERP`).
   This segment contains a null-terminated ASCII string specifying the target filesystem path to the dynamic linker/loader:
   ```text
   [Requesting program interpreter: /lib/ld-linux-armhf.so.3]
   ```
2. It creates a program header segment of type `PT_DYNAMIC`. Inside this segment, dynamic tags of type `DT_NEEDED` list every required shared library:
   ```text
   0x00000001 (NEEDED) Shared library: [libc.so.6]
   ```
3. When `execve()` runs on the target, the kernel checks `PT_INTERP`. If present, the kernel **does not run the application binary directly**. Instead, it loads the interpreter into memory and hands control to `/lib/ld-linux-armhf.so.3`.
4. The interpreter parses `DT_NEEDED`, searches `/lib`, `/usr/lib`, and paths configured in `/etc/ld.so.cache` or `DT_RPATH`/`DT_RUNPATH`, maps the shared libraries, performs relocations, and finally jumps to the application's `main()`.
5. If `/lib/ld-linux-armhf.so.3` is missing from the target rootfs, `execve()` returns `-ENOENT` (`No such file or directory`), causing the shell to print `sh: ./app: not found`. The missing file is **the interpreter**, NOT `./app`!

### 3.3 Static Linking (`-static`)
When compiled with `-static`:
- The linker resolves all library routines (e.g. `printf`, `exit`, `malloc`) directly from archive libraries (`libc.a`) and embeds the machine code into the binary.
- `PT_INTERP` is **completely absent**.
- `PT_DYNAMIC` and `DT_NEEDED` are **completely absent**.
- Static linkage eliminates the requirement for an ELF interpreter and shared objects, enabling execution in an environment where `/lib` contains no shared libraries.
- **Portability Boundary**: The absence of `PT_INTERP` does **not** guarantee universal execution on "any ARMv7 Linux kernel". The binary still strictly requires:
  1. Instruction set and CPU compatibility (ARMv7-A vs ARMv6/ARMv8);
  2. Floating-point ABI compatibility (VFP/NEON hard-float calling convention);
  3. Kernel syscall ABI compatibility (e.g. minimum supported kernel version for libc syscall wrappers);
  4. Application-level runtime dependencies (e.g. `/dev`, `/proc`, `/sys` mounts, environment variables).

> [!IMPORTANT]
> **Static Linkage Proof Contract**:  
> Running `readelf -h` alone **does NOT prove static linkage**! `readelf -h` only shows machine architecture, ELF class, and flags. Both static and dynamic ARM binaries produce almost identical `readelf -h` output (`Type: EXEC`, `Machine: ARM`).  
> To prove static linkage, you MUST inspect program headers with `readelf -l` (confirming absence of `INTERP`) or dynamic sections with `readelf -d` (confirming absence of `DYNAMIC`).

---

## 4. Hands-On Labs

### Lab 1.1 — Cross-Compiling and Auditing Target ELF Headers
Location: [`labs/01-host-vs-target/`](labs/01-host-vs-target/)
- Cross-compile `hello_target.c` with `${CROSS_COMPILE}gcc`.
- Run `readelf -h hello_target` and verify:
  - `Class: ELF32`
  - `Data: 2's complement, little endian`
  - `Machine: ARM`
  - `Flags: 0x5000400, Version5 EABI, hard-float ABI`
- Attempt execution on host and record exact `Exec format error` output.

### Lab 1.2 — Inspecting the Target Sysroot
Location: [`labs/02-target-tuple-sysroot/`](labs/02-target-tuple-sysroot/)
- Run `${CROSS_COMPILE}gcc -print-sysroot` to discover the target root directory on host.
- Locate the target standard C library (`libc.so.6`) and dynamic linker (`ld-linux-armhf.so.3`).
- Contrast the sysroot headers (`usr/include`) with host headers (`/usr/include`).

### Lab 1.3 — Dynamic ELF Dissection: `PT_INTERP` and `DT_NEEDED`
Location: [`labs/03-dynamic-elf/`](labs/03-dynamic-elf/)
- Cross-compile `dynamic_app.c` dynamically.
- Inspect program headers: `readelf -l dynamic_app | grep -A1 INTERP`.
- Inspect dynamic section: `readelf -d dynamic_app | grep NEEDED`.
- Identify the exact loader pathname required on target.

### Lab 1.4 — Static ELF Dissection: Complete Self-Containment
Location: [`labs/04-static-elf/`](labs/04-static-elf/)
- Cross-compile `static_app.c` with `-static`.
- Verify the complete absence of `INTERP` using `readelf -l static_app`.
- Verify the complete absence of `DYNAMIC` using `readelf -d static_app`.
- Compare file sizes between static and dynamic binaries and explain the trade-off.

### Lab 1.5 — Artifact Audit Scripting
Location: [`labs/05-artifact-audit/`](labs/05-artifact-audit/)
- Implement a shell audit tool that processes a directory of binary artifacts and categorizes each into: `HOST_ELF`, `TARGET_DYNAMIC`, `TARGET_STATIC`, or `NOT_ELF`.

---

## 5. Deliberate Seeded Faults

### Fault F01 — Binary Architecture Mismatch
Location: [`faults/F01-wrong-architecture/`](faults/F01-wrong-architecture/)
- **Symptom**: Attempting to run a target utility gives: `cannot execute binary file: Exec format error`.
- **Diagnostic Loop**:
  1. Own Description: Kernel refused to load the binary executable.
  2. Hypotheses:
     - Binary is built for host x86-64 instead of ARM.
     - Binary is 64-bit ARM (AArch64) running on 32-bit ARM kernel.
     - Binary ELF magic number is corrupted.
  3. Experiment: Run `readelf -h app` and `file app`.
  4. Evidence: `readelf -h` shows `Machine: Advanced Micro Devices X86-64` (or host arch).
  5. Narrow Scope: Makefile invoked `gcc` instead of `$(CROSS_COMPILE)gcc`.
  6. Root Cause: Makefile compiler variable unconfigured or overridden by host environment.
  7. Fix: Explicitly specify `CC = $(CROSS_COMPILE)gcc`.
  8. Regression: Rebuild, verify `Machine: ARM`, verify target execution.

### Fault F02 — Missing Dynamic Loader
Location: [`faults/F02-missing-loader/`](faults/F02-missing-loader/)
- **Symptom**: Executing `./app` produces `sh: ./app: not found` (or `No such file or directory`), but `test -f ./app` returns 0!
- **Diagnostic Loop**:
  1. Own Description: Shell reports file missing even though the binary file exists on disk.
  2. Hypotheses:
     - Missing dynamic interpreter specified in `PT_INTERP`.
     - Missing shared library in `DT_NEEDED`.
     - Missing execute permissions (`chmod +x`).
  3. Experiment: Run `readelf -l app | grep interpreter` to determine the exact requested interpreter path, then check if that path exists in the target rootfs.
  4. Evidence: `PT_INTERP` requests `/lib/ld-linux-armhf.so.3`. In the rootfs fixture, `/lib/ld-linux-armhf.so.3` is absent (or rootfs only has `ld-musl-armhf.so.1`).
  5. Narrow Scope: The binary file is present and executable, but the kernel's `load_elf_binary()` fails when opening the interpreter path.
  6. Root Cause: Glibc dynamic binary placed into a rootfs lacking the glibc dynamic linker.
  7. Fix: Copy `/lib/ld-linux-armhf.so.3` and dependencies from the toolchain sysroot, or recompile with `-static`.
  8. Regression: Re-execute in target environment, verify clean exit.

---

## 6. AI-Free Challenge & Module Gate

### Challenge: Unfamiliar Binary Audit Tool
Location: [`challenge/`](challenge/)
You are given unknown binary artifacts and an isolated rootfs structure. You must write an audit tool [`challenge/audit_tool.c`](challenge/audit_tool.c) or script that:
1. Determines architecture without relying on file extension;
2. Extracts interpreter requirements;
3. Validates whether rootfs has all required loaders.

### Gate: Three-Artifact Identification
Location: [`gate/`](gate/)
Given three opaque artifacts (`candidate_alpha`, `candidate_beta`, `candidate_gamma`), produce an evidence-backed manifest determining:
- Which is host-compiled (Wrong Architecture)?
- Which is dynamic target ELF missing its loader?
- Which is static target ELF ready for a minimal rootfs?

Fill out [`gate/gate_manifest.template`](gate/gate_manifest.template) with verifiable `readelf` output.

---

## 7. Verification & Assessment
- Learner-safe automated verification: [`scripts/verify_m01.sh`](scripts/verify_m01.sh) (`make check`).
  It validates lab/fault artifacts and confirms the assessment fixtures are provisioned and readable.
  It deliberately does **not** grade Challenge/Gate classifications — that is your analysis work.
- Assessment grading is performed separately during review; learner workflows are fully self-contained.
- Assessment fixtures under `challenge/fixtures/` and `gate/fixtures/` are pre-provisioned opaque artifacts.
  Do not try to regenerate them; analyze them with GNU Binutils.
