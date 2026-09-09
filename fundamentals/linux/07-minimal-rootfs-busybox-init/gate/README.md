# P3-M03 AI-Free Module Gate — Manual Rootfs Assembly & Boot Verification

## 1. Exam Briefing

This is the official competency Gate for **P3-M03: Manual Minimal Rootfs, BusyBox, Pseudo-Filesystems & PID 1 Init Lifecycle**.

A defective root filesystem staging tree has been pre-provisioned for you (opaque, reviewer-authored, rotated from the Challenge family). It contains subtle defects across:

1. file permissions;
2. applet symlink targets;
3. pseudo-filesystem mount initialization.

Your mission:

1. Provision the working copy:
   ```bash
   make provision
   ```
2. Audit the damaged staging tree, formulate hypotheses, and collect observable evidence.
3. Repair all structural, permission, and initialization defects in `build/candidate_rootfs/`.
4. Package the corrected filesystem:
   ```bash
   make package
   ```
5. Self-check, then prove interactive shell boot in QEMU with active `/proc` and `/sys` mounts.

## 2. Assessment Conditions (AI-Free)

> [!CAUTION]
> - **AI-Free Exam Mode**: No AI coding assistants or pre-generated answers permitted.
> - **Strict Assessment Isolation**: Do NOT access or import grading references or hidden evaluation suites. The exact defect set is hidden.
> - **Pass Criteria**:
>   - Rootfs structure strictly adheres to minimal FHS layout;
>   - Multicall binary is verified static ARM ELF (no `PT_INTERP`, no `DT_NEEDED`);
>   - `/init` or `/sbin/init` has executable mode;
>   - All applet symlinks resolve inside the tree;
>   - Pseudo-filesystems (`proc`, `sysfs`, `devtmpfs`) are mounted by ACTIVE commands (comments/`echo` text does not count);
>   - Packaged `build/candidate.cpio.gz` unpacks to an equally valid tree;
>   - Interactive shell is reachable and `ps` reports valid PID 1 process state.

## 3. Examination Commands

```bash
make provision   # stage the opaque defective tree (no answers inside)
make package     # package your repaired candidate
make check       # learner-safe structure self-check (not the final grade)
```

Final grading is performed by the reviewer oracle against your `build/candidate_rootfs/` tree and `build/candidate.cpio.gz` archive.
