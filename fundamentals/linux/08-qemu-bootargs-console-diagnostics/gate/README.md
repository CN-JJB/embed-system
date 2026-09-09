# P3-M04 AI-Free Module Gate — Canonical Boot Configuration & Milestone Certification

## 1. Objective

This Gate certifies your autonomous capability to:
1. Configure canonical QEMU machine flags and boot parameters for the Cortex-A7 `virt` platform.
2. Formulate correct kernel command-line arguments combining early debug console (`earlycon`) with normal runtime console handoff (`console=ttyAMA0,115200`).
3. Correctly specify rootfs initialization (`rdinit=/init`).
4. Validate that boot milestone progression occurs deterministically in strict chronological order.

---

## 2. Gate Requirements

You must deliver an executable launch configuration script at:
```text
gate/build/gate_boot_config.sh
```

The script must:
1. Set the canonical machine flags: `-machine virt,highmem=off,gic-version=2`
2. Specify CPU: `-cpu cortex-a7`
3. Allocate memory: `-m 512M`
4. Set SMP: `-smp 1`
5. Enable headless terminal: `-nographic`
6. Supply bootargs via `-append`:
   - `earlycon=pl011,0x09000000`
   - `console=ttyAMA0,115200`
   - `rdinit=/init`
7. Successfully boot to the interactive shell and produce an auditable log.

---

## 3. Assessment Conditions (AI-Free)

> [!IMPORTANT]
> - **AI-Free Mode**: You must formulate and verify the parameters independently without AI generation.
> - **Canonical Alignment**: Do not use ad-hoc machine options or uncalibrated memory settings.
> - **Assessment Integrity**: Do not inspect evaluation or grading assets before submission.

---

## 4. Verification

To build and run the gate verification:
```bash
make gate-build
make check
```
