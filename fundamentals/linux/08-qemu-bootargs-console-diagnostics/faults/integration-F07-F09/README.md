# Boot-Chain Fault Taxonomy & Integration (F04–F09)

> All rows calibrated on real Linux 6.18.50 + real BusyBox 1.36.1 initramfs. Init-fallback semantics per `init/main.c`: a failed `rdinit=` exec falls through to `/sbin/init`, `/etc/init`, `/bin/init`, `/bin/sh` — a panic requires every candidate to be unusable (or the early access check to reroute, F04).

## 1. Objective

Integrate the full set of boot failure modes (F04 through F09) into a unified diagnostic decision tree. Given an unknown boot-chain failure, systematically classify the defect into one of four primary failure domains:

```text
[Failure Domain 1] Kernel-Side Boot & Resource Failure (F04, F06)
                   - Symptom: VFS panic from a rerouted root mount (F04) or OOM deadlock panic / early stall (F06).
                   - Distinguishing Feature: Kernel fails before or during rootfs-to-userspace transition.

[Failure Domain 2] Console Visibility & Handoff Failure (F05)
                   - Symptom: Total silence, or early-only output ending at 'Warning: unable to open an initial console'.
                   - Distinguishing Feature: Kernel is alive (earlycon proves it); output is unrouted.

[Failure Domain 3] Init Execution & Permission Failure (F07, F08)
                   - Symptom: 'Failed to execute … (error -2/-13)' walked across the fallback list, then 'No working init found'.
                   - Distinguishing Feature: Occurs at the exact moment of userspace transition; a panic here PROVES all fallbacks were unusable.

[Failure Domain 4] Userspace & Pseudo-Filesystem Failure (F09)
                   - Symptom: Real shell reachable; real 'ps' prints a header-only empty table; 'mount: no /proc/mounts'.
                   - Distinguishing Feature: Kernel does NOT panic; failure is confined to userspace mounts.
```

---

## 2. Master Diagnostic Decision Tree

```text
                                  Boot Attempt
                                       |
                   +-------------------+-------------------+
                   |                                       |
             Output Visible?                         Terminal Silent?
                   |                                       |
         +---------+---------+                             v
         |                   |                   Inject earlycon=...
   Reaches Userspace?   Panics in Kernel?                  |
         |                   |                     +-------+-------+
         v                   v                     |               |
   Shell Prompt?       Panic Location?       Output Appears?   Still Silent?
         |                   |                     |               |
    +----+----+         +----+----+                v               v
    |         |         |         |         Console Mismatch  Early Hang /
   ps OK?  ps EMPTY?  VFS/root? At Init?      (F05)         Assembly Lockup
    |         |         |         |
    v         v         v         v
  HEALTHY  Missing    Bad        Unusable Init +
  SYSTEM    /proc     rdinit     No Fallbacks
            (F09)    (F04/F06)    (F07/F08)
```

---

## 3. Comparative Fault Reference Matrix

| Fault ID | Family | Observable Evidence (real runtime) | Kernel Panic? | Root Cause | Discriminating Experiment |
|---|---|---|---|---|---|
| **F04** | Bootargs / Root | `check access for rdinit=… failed: -2, ignoring` → `VFS: Unable to mount root fs on unknown-block(0,0)` | YES (VFS) | Nonexistent `rdinit=` path reroutes to block-root mount | Check `Kernel command line:` + archive listing |
| **F05** | Console Mismatch | Silence; with earlycon: `Warning: unable to open an initial console`, then secondary `Attempted to kill init!` | Secondary only | `console=ttyS0` instead of `ttyAMA0` | Enable `earlycon=pl011,0x09000000` |
| **F06** | Insufficient RAM | `mem=32M`: `Out of memory…` → `System is deadlocked on memory` (PRIMARY); `mem=8M`: CMA warnings then timeout-hang; `-m 8M`: QEMU refusal | YES (PRIMARY) / hang / refusal | `mem=` restriction or short `-m` | Remove `mem=` override; run `calibrate_f06_ram.sh` |
| **F07** | Unusable Init Content | `Failed to execute … (error -2)` walked across fallbacks → `No working init found` | YES | Init passes access check but fails `execve`; no fallbacks | Archive listing + mode/manifest audit |
| **F08** | Init Permissions | `Failed to execute /init (error -13)` walked across fallbacks → `No working init found` | YES | `/init` lacks `+x`; no fallbacks | Check mode bits in CPIO metadata |
| **F09** | Unmounted Pseudo-FS | Real `ps` header-only empty table; `mount: no /proc/mounts`; repair via `mount -t proc none /proc` | NO | Init omitted ACTIVE `proc` mount | Run `mount` inside shell |
