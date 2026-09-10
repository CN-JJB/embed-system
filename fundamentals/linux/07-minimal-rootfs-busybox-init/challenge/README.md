# P3-M03 AI-Free Challenge — Production BusyBox Init & inittab Configuration

## 1. Challenge Briefing

In Lab 3.4, you used a simple shell script (`/init`) to bootstrap userspace. Production Embedded Linux systems typically use a dedicated init supervisor like **BusyBox `/sbin/init`** configured through `/etc/inittab`.

A defective candidate tree has been pre-provisioned for you (opaque, reviewer-authored). It is a **real BusyBox 1.36.1 tree**: `/bin/busybox` is the verified static ARM build artifact and the applet entries are genuine BusyBox applet links. Only the *wiring and configuration* are damaged, drawn from the families you practiced in the labs and faults:

- file permissions;
- applet symlink targets;
- pseudo-filesystem mount initialization;
- production init configuration (`/etc/inittab`, `/etc/init.d/rcS`).

Your mission:

1. Provision the working copy:
   ```bash
   make provision
   ```
2. Apply the disciplined diagnostic loop (symptom → hypotheses → evidence → root cause → fix → regression) to find every defect in `build/candidate_rootfs/`.
3. Repair all defects so the tree satisfies the production contract below.
4. Package and self-check:
   ```bash
   make package && make check
   ```
5. Boot the packaged `build/candidate.cpio.gz` in QEMU with `rdinit=/sbin/init`, press Enter at the console prompt, and verify `ps` shows `init` as PID 1.

> **Scored boot selector.** The scored production path is `rdinit=/sbin/init`: the kernel executes the real BusyBox `init` applet as PID 1, which then consumes `/etc/inittab`. The Lab 3.4 `/init` shell script stays in the tree (and must exist and be executable), but it is not the scored production init path.

## 2. Production Contract (scored)

Your repaired candidate must satisfy:

1. **Init executable**: `/sbin/init` resolves to the real BusyBox binary inside the tree; `/init` exists and is executable.
2. **Inittab (`/etc/inittab`)**: a `sysinit` line targeting `/etc/init.d/rcS`, and an `askfirst` line on `ttyAMA0` launching `-/bin/sh`.
3. **Startup script (`/etc/init.d/rcS`)**: executable, with ACTIVE mounts for `/proc` (`proc`) and `/sys` (`sysfs`). Comment or `echo` text mentioning mounts does not count.
4. **Applets**: `/bin/sh`, `/bin/ls`, `/bin/ps`, `/bin/mount`, `/bin/echo`, `/bin/cat` resolve to the real BusyBox binary.
5. **Provider identity**: the multicall/init provider must be a **real BusyBox 1.36.1 artifact** (static ARM, BusyBox identity and applet table). A synthetic teaching multicall — or any other renamed binary — is not a BusyBox submission and cannot be scored.
6. **Runtime**: booting your packaged `build/candidate.cpio.gz` reaches real BusyBox init as PID 1, runs your `rcS`, hands the console over via `askfirst` (`Please press Enter to activate this console.`), and after Enter `/ # ` appears while `ps` lists `init` as PID 1.

## 3. Assessment Rules (AI-Free)

> [!IMPORTANT]
> - **AI-Free Mode**: You may consult official upstream documentation (BusyBox FAQ, Linux kernel documentation, man pages `inittab(5)`), but you must NOT use automated AI code generation.
> - **Assessment Integrity**: You must NOT inspect grading reference solutions or hidden test fixtures until your attempt is submitted and scored. The exact defect set is hidden; do not look for it outside `fixtures/defective_rootfs/` and your working copy.
> - **Verification Evidence**: A valid submission requires the repaired `build/candidate_rootfs/` tree plus the packaged `build/candidate.cpio.gz`.

## 4. Commands

```bash
make provision   # stage the opaque defective tree (no answers inside)
make package     # package your repaired candidate
make check       # learner-safe structure + real-BusyBox identity self-check
```
