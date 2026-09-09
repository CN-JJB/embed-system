# P3-M03 AI-Free Module Gate — Manual Rootfs Assembly & Boot Verification

## 1. Exam Briefing

This is the official competency Gate for **P3-M03: Manual Minimal Rootfs, BusyBox, Pseudo-Filesystems & PID 1 Init Lifecycle**.

You are presented with a defective root filesystem staging tree containing subtle defects across:
1. File permissions;
2. Applet symlink targets;
3. Pseudo-filesystem mount initialization.

Your mission:
- Audit the damaged staging tree;
- Formulate hypotheses and collect observable evidence;
- Repair all structural, permission, and initialization defects;
- Package the corrected filesystem into `rootfs_gate.cpio.gz`;
- Verify that QEMU boots to an interactive shell with active `/proc` and `/sys` mounts.

---

## 2. Assessment Conditions (AI-Free)

> [!CAUTION]
> - **AI-Free Exam Mode**: No AI coding assistants or pre-generated answers permitted.
> - **Strict Assessment Isolation**: Do NOT access or import grading references or hidden evaluation suites.
> - **Pass Criteria**:
>   - Rootfs structure strictly adheres to minimal FHS layout;
>   - BusyBox binary is verified static ARM ELF (no `PT_INTERP`, no `DT_NEEDED`);
>   - `/init` or `/sbin/init` has executable mode (`0755`);
>   - Pseudo-filesystems (`proc`, `sysfs`, `devtmpfs`) are mounted cleanly;
>   - Interactive shell is reachable and `ps` reports valid PID 1 process state.

---

## 3. Examination Commands

1. Build the gate candidate:
   ```bash
   make gate-build
   ```

2. Run learner-safe validation:
   ```bash
   make check
   ```
