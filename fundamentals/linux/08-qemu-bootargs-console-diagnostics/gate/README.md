# P3-M04 AI-Free Module Gate — Canonical Boot Configuration & Milestone Certification

## 1. Objective

This Gate certifies your autonomous capability to:

1. Configure canonical QEMU machine flags and boot parameters for the Cortex-A7 `virt` platform.
2. Formulate correct kernel command-line arguments combining early debug console (`earlycon`) with normal runtime console handoff (`console=ttyAMA0,115200`).
3. Correctly specify rootfs initialization (`rdinit=/init`).
4. Validate that boot milestone progression occurs deterministically in strict chronological order, bound to YOUR OWN runtime capture.

## 2. Gate Requirements

A non-canonical starter has been pre-provisioned (opaque, reviewer-authored). It is deliberately not the canonical answer: you must diagnose it against the module contract and author the canonical candidate independently.

1. Provision the workspace:
   ```bash
   make provision
   ```
2. Author the canonical launch configuration at:
   ```text
   gate/build/candidate_boot_config.sh
   ```
   The candidate must satisfy the canonical contract (machine, CPU, memory, SMP, headless terminal, single `console=ttyAMA0,115200`, `earlycon`, `rdinit=/init`). Copying the starter verbatim cannot pass.
3. Capture FRESH runtime evidence with your candidate:
   ```bash
   make capture
   ```
   This boots the pinned real kernel + real BusyBox initramfs with YOUR BOOTARGS and saves `gate/build/candidate_boot.log`.
4. Self-check:
   ```bash
   make check
   ```

Final grading binds YOUR log to YOUR BOOTARGS (kernel command line, version, console handoff, init, real BusyBox userspace response) and re-executes your launch independently. A stock reference log cannot satisfy the runtime portion.

## 3. Assessment Conditions (AI-Free)

> [!IMPORTANT]
> - **AI-Free Mode**: You must formulate and verify the parameters independently without AI generation.
> - **Canonical Alignment**: Do not use ad-hoc machine options or uncalibrated memory settings.
> - **Assessment Integrity**: Do not inspect evaluation or grading assets before submission. The starter's exact defect set is hidden.

## 4. Verification

```bash
make provision
make capture
make check
```
