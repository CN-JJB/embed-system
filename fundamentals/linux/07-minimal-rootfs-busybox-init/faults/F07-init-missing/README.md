# Fault F07 — Init Missing / Unusable Path

> Calibrated on real Linux 6.18.50 (`7cfc41f8e80f11ffa8382ed1a505154ceffb79c7`) + real BusyBox 1.36.1 initramfs. Source: `init/main.c` (`run_init_process`, `try_to_run_init_process`, `kernel_init`).

## 1. Symptom

When the requested init *passes* the kernel's early access check but *fails* at `execve()` time — and every fallback candidate is also unusable — the kernel walks the whole fallback list and then panics:

```text
[    1.168831] Run /sbin/myinit as init process
[    1.171210] Failed to execute /sbin/myinit (error -2)
[    1.171320] Run /sbin/init as init process
[    1.171705] Run /etc/init as init process
[    1.171935] Run /bin/init as init process
[    1.172147] Run /bin/sh as init process
[    1.172488] Kernel panic - not syncing: No working init found.  Try passing init= option to kernel. See Linux Documentation/admin-guide/init.rst for guidance.
```

Reproduced with a real rootfs where `/sbin/myinit` exists (so the access check passes) but cannot execute — here a script whose interpreter is missing, so `execve()` returns `-ENOENT` (`-2`) — and `/sbin/init`, `/etc/init`, `/bin/init`, `/bin/sh` were all removed.

## 1b. Why a Bad `rdinit=` Does Not Always Panic

`kernel_init()` tries, in order: the `rdinit=` target, then `init=`, then `CONFIG_DEFAULT_INIT` (empty in our build), then the hardcoded fallback list `/sbin/init`, `/etc/init`, `/bin/init`, `/bin/sh`. A *failed* `rdinit=` exec only panics when **all** of those are unusable. On the canonical rootfs — which ships working `/sbin/init` and `/bin/sh` — a non-executable `/init` merely logs `Failed to execute /init (error -13)` and continues with `Run /sbin/init as init process` (BusyBox init, `Please press Enter to activate this console.`). Never assume `No working init found` from a bad `rdinit=` alone: check which fallback caught the boot.

(If the `rdinit=` path does not exist at all, the failure happens even earlier — at the access check — and routes to the VFS block-root panic instead. See F04.)

---

## 2. Full Diagnostic Discipline Walkthrough

### Step 1: Own Description
The kernel unpacks the initramfs and attempts the requested init, which fails at exec time; every fallback also fails, so the kernel panics with no userspace ever starting.

### Step 2: 3–5 Hypotheses
1. The requested init exists but its interpreter/loader is missing (bad shebang, missing dynamic linker) → `-ENOENT` at exec.
2. The requested init lacks the executable bit → `-EACCES` (see F08).
3. The archive genuinely lacks the requested path AND all fallbacks (check the access-check line: if present, this is the F04 VFS route instead).
4. The initramfs failed to unpack, leaving an empty root.

### Step 3: Discriminating Experiment
Inspect archive contents and modes on the host:
```bash
zcat rootfs.cpio.gz | cpio -t 2>/dev/null | grep -E "init|bin/sh"
python3 ../scripts/pycpio.py --list /tmp/a.cpio | grep -E "init|bin/sh"
```

### Step 4: Observable Evidence
The log names the exact failing stage: `Failed to execute /sbin/myinit (error -2)` is an *exec-time* failure (the `Run …` line precedes it), followed by one `Run …` line per fallback candidate, then the panic. Contrast F04, where `check access for rdinit=… failed` appears and no `Run …` line is ever printed for the bad path.

### Step 5: Narrow Scope
Unpacker, drivers, and archive are healthy. The fault is the unusable init content plus absent fallbacks.

### Step 6: Root Cause
`execve()` on the requested init fails (`-2` here), and no fallback candidate exists to catch the boot.

### Step 7: Fix
Provide a working init at the requested path (or point `rdinit=` at the real `/init`), and restore the canonical fallback applets:
```bash
-append "earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init"
```

### Step 8: Regression Check
Boot in QEMU and verify `Run /init as init process` → `REAL-BUSYBOX-INIT-READY` → real BusyBox shell, with no `Failed to execute` line.
