# Boot-Chain Fault Taxonomy & Integration (F04–F09)

## 1. Objective

Integrate the full set of boot failure modes (F04 through F09) into a unified diagnostic decision tree. Given an unknown boot-chain failure, systematically classify the defect into one of four primary failure domains:

```text
[Failure Domain 1] Kernel-Side Boot & Resource Failure (F04, F06)
                   - Symptom: Kernel panic during early boot, OOM deadlock, or VFS panic.
                   - Distinguishing Feature: Kernel crash occurs before or during rootfs mount.

[Failure Domain 2] Console Visibility & Handoff Failure (F05)
                   - Symptom: Total silence or output ceases after decompressor / earlycon.
                   - Distinguishing Feature: Kernel is alive in userspace, but output is unrouted.

[Failure Domain 3] Init Execution & Permission Failure (F07, F08)
                   - Symptom: Kernel panic: "Attempted to kill init!" or "No working init found".
                   - Distinguishing Feature: Occurs at the exact moment of userspace transition.

[Failure Domain 4] Userspace & Pseudo-Filesystem Failure (F09)
                   - Symptom: Interactive shell prompt reachable, but ps, top, or telemetry fails.
                   - Distinguishing Feature: Kernel does NOT panic; failure is confined to userspace.
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
   ps OK?  ps Fails?  Before VFS? At Init?      (F05)         Assembly Lockup
    |         |         |         |
    v         v         v         v
  HEALTHY  Missing    Bad Root/  Missing Init /
  SYSTEM    /proc     OOM RAM    Permissions
            (F09)    (F04/F06)    (F07/F08)
```

---

## 3. Comparative Fault Reference Matrix

| Fault ID | Family | Observable Evidence | Kernel Panic? | Root Cause | Discriminating Experiment |
|---|---|---|---|---|---|
| **F04** | Bootargs / Root | `Waiting for root device` or `Failed to execute ... (error -2)` | YES | Wrong `root=` or `rdinit=` | Check `/proc/cmdline` or QEMU `-append` |
| **F05** | Console Mismatch | Terminal silent; with earlycon: `Warning: unable to open an initial console` | NO | `console=ttyS0` instead of `ttyAMA0` | Enable `earlycon=pl011,0x09000000` |
| **F06** | Insufficient RAM | `Out of memory... Kernel panic: System is deadlocked on memory` | YES | `mem=32M` or insufficient RAM | Remove `mem=` override |
| **F07** | Missing Init | `Failed to execute ... (error -2)` followed by panic | YES | Init executable path missing in archive | `zcat rootfs.cpio.gz \| cpio -t` |
| **F08** | Init Permissions | `Failed to execute ... (error -13)` followed by panic | YES | Init executable missing `+x` mode bit | Check mode bits in cpio listing |
| **F09** | Unmounted Pseudo-FS | `ps: /proc: No such file or directory` inside shell | NO | `/init` omitted `mount -t proc none /proc` | Run `mount` inside shell |
