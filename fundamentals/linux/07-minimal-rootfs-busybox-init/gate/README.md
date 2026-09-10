# P3-M03 AI-Free Module Gate — Real-BusyBox Rootfs Assembly & Boot Verification

## 1. Exam Briefing

This is the official competency Gate for **P3-M03: Manual Minimal Rootfs, BusyBox, Pseudo-Filesystems & PID 1 Init Lifecycle**.

A defective root filesystem candidate is provisioned for you from your verified local BusyBox staging plus a small assessment delta (rotated from the Challenge family). It is a **real BusyBox 1.36.1 tree**: the multi-call binary at `/bin/busybox` is the verified build artifact, and the applets are genuine BusyBox applet links. Only the *wiring and configuration* are damaged, across:

1. file permissions;
2. applet symlink targets;
3. pseudo-filesystem mount initialization;
4. production init configuration.

Your mission:

1. Build the verified staging once (if not already present):
   ```bash
   CROSS_COMPILE=<prefix> bash ../scripts/build_real_busybox.sh
   ```
2. Provision the working copy:
   ```bash
   make provision
   ```
   This injects the verified real BusyBox base plus the small assessment
   delta into `build/candidate_rootfs/` (the expanded binary + applet
   forest are never tracked in Git).
2. Audit the damaged staging tree, formulate hypotheses, and collect observable evidence.
3. Repair all structural, permission, and initialization defects in `build/candidate_rootfs/`.
4. Package the corrected filesystem:
   ```bash
   make package
   ```
5. Prove it on the real platform: the Gate boots **your packaged `build/candidate.cpio.gz`** against the pinned Linux 6.18.50 `zImage` with `rdinit=/sbin/init`.

## 2. Scored Boot Contract (production BusyBox init)

The scored capability is **production BusyBox init**, not a shell-script init:

| Element | Scored requirement |
|---|---|
| Provider | real BusyBox 1.36.1 `/bin/busybox` (static ARM, no `PT_INTERP`/`DT_NEEDED`) |
| PID 1 | `/sbin/init` resolving to the real BusyBox binary, selected by `rdinit=/sbin/init` |
| `/etc/inittab` | `::sysinit:/etc/init.d/rcS` **and** `ttyAMA0::askfirst:-/bin/sh` |
| `/etc/init.d/rcS` | executable, with ACTIVE `mount -t proc … /proc` and `mount -t sysfs … /sys` |
| Console | `askfirst` handoff: the console must be activated by pressing Enter |
| Runtime | `ps` shows `init` as PID 1 and the interactive `/bin/sh` from inittab |
| Archive | `build/candidate.cpio.gz` unpacks to an equally valid tree and is the artifact that is booted |

`/init` (the Lab 3.4 shell-script PID 1 for the `rdinit=/init` path) must also exist and be executable: it is the reference model you built earlier and it remains part of the tree contract. It is **not** the scored production init path.

## 3. Assessment Conditions (AI-Free)

> [!CAUTION]
> - **AI-Free Exam Mode**: No AI coding assistants or pre-generated answers permitted.
> - **Strict Assessment Isolation**: Do NOT access or import grading references or hidden evaluation suites. The exact defect set is hidden.
> - **Pass Criteria**:
>   - Rootfs structure strictly adheres to minimal FHS layout;
>   - The multi-call/init provider is a **real BusyBox 1.36.1 artifact** — a synthetic teaching multicall or any other binary is not a BusyBox submission;
>   - `/init` and `/sbin/init` are executable, and `/sbin/init` resolves to the real BusyBox binary;
>   - All applet symlinks resolve inside the tree;
>   - Pseudo-filesystems (`proc`, `sysfs`, `devtmpfs`) are mounted by ACTIVE commands (comments/`echo` text does not count);
>   - Packaged `build/candidate.cpio.gz` unpacks to an equally valid tree, and **booting that archive** reaches real BusyBox init as PID 1 with the interactive shell and `ps` PID-1 evidence.

## 4. Examination Commands

```bash
make provision   # stage the defective candidate from verified staging + small delta (no answers inside)
make package     # package your repaired candidate (REQUIRED for runtime grading)
make check       # learner-safe self-check (not the final grade)
```

Final grading is performed by the reviewer oracle: static artifact/contract grading of your tree plus `build/candidate.cpio.gz`, then a **fresh QEMU boot of your packaged archive** against the pinned real kernel — a canonical rootfs is never booted in place of yours.
