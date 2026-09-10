# P3-M04 AI-Free Module Gate — Canonical Boot Configuration & Milestone Certification

## 1. Objective

This Gate certifies your autonomous capability to:

1. Configure canonical QEMU machine flags and launch parameters for the Cortex-A7 `virt` platform.
2. Formulate correct kernel command-line arguments combining early debug console (`earlycon`) with normal runtime console handoff (`console=ttyAMA0,115200`).
3. Correctly specify rootfs initialization (`rdinit=/init`).
4. Validate that boot milestone progression occurs deterministically in strict chronological order, bound to YOUR OWN runtime capture.

## 2. Candidate Submission Format: a data-only launch manifest

Your candidate is a **data-only manifest** — declarative `KEY=value` lines, one definition per key. It is not shell: there is no command, no substitution, no environment expansion. This exists so that the declaration and the executed invocation cannot disagree.

```text
MACHINE=virt,highmem=off,gic-version=2
CPU=cortex-a7
MEM=512M
SMP=1
NOGRAPHIC=true
BOOTARGS=earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init
```

A single trusted runner parses this manifest, validates the values, builds the real `qemu-system-arm` command line from **your** values, records that command line as provenance, and executes exactly it. The reviewer re-executes the same manifest and grades the executed configuration, so a correct-looking declaration that the runner does not consume cannot pass — and neither can a correct declaration whose invocation is overridden.

## 3. Gate Requirements

A non-canonical starter manifest has been pre-provisioned (opaque, reviewer-authored). It is deliberately not the canonical answer: diagnose it against the module contract and author the canonical candidate independently.

1. Provision the workspace:
   ```bash
   make provision
   ```
2. Author the canonical launch manifest at:
   ```text
   gate/build/candidate_boot_manifest.conf
   ```
   The candidate must satisfy the canonical contract (machine `virt,highmem=off,gic-version=2`, `cortex-a7`, `512M`, `-smp 1`, headless serial, exactly one `console=ttyAMA0,115200`, `earlycon=pl011,0x09000000`, `rdinit=/init`). Unknown keys, duplicate keys, commented-out declarations, non-declarative shell content, and command substitution are all rejected. Copying the starter verbatim cannot pass.
3. Capture FRESH runtime evidence from YOUR manifest:
   ```bash
   make capture
   ```
   This derives the QEMU argv from your manifest, records it as `gate/build/candidate_boot.argv`, boots the pinned real kernel + real BusyBox initramfs with exactly that configuration, and saves `gate/build/candidate_boot.log`.
4. Self-check:
   ```bash
   make check
   ```
   The self-check validates the manifest contract and then binds the captured provenance + console log back to the manifest.

## 4. How the Gate is graded

Final grading:

1. validates your manifest against the canonical contract;
2. checks that your submitted executed-argv provenance matches the manifest's declarations **and** the submitted console log — a stock reference log cannot satisfy this, and a declaration that was never executed cannot either;
3. independently **re-executes your manifest** through the trusted runner and requires the fresh provenance + fresh console capture to prove machine/CPU/RAM/SMP/nographic/kernel/initrd/bootargs binding, chronological boot milestones, console handoff, PID-1 launch, and real BusyBox userspace responses, with guest-visible RAM and CPU count matching the executed `-m`/`-smp` values.

## 5. Assessment Conditions (AI-Free)

> [!IMPORTANT]
> - **AI-Free Mode**: You must formulate and verify the parameters independently without AI generation.
> - **Canonical Alignment**: Do not use ad-hoc machine options or uncalibrated memory settings.
> - **Assessment Integrity**: Do not inspect evaluation or grading assets before submission. The starter's exact defect set is hidden.

## 6. Verification

```bash
make provision
make capture
make check
```
