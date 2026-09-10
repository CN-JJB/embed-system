# P3-M04 AI-Free Challenge — Silent Boot Failure Isolation

## 1. Challenge Briefing

A broken appliance launch configuration has been pre-provisioned (opaque, reviewer-authored). Booting it terminates in complete silence immediately after the decompressor output:

```text
Uncompressing Linux... done, booting the kernel.
(Terminal completely silent; system appears hung)
```

Your mission — apply the disciplined diagnostic loop:

$$\text{Symptom} \longrightarrow \text{Own Description} \longrightarrow \text{3–5 Hypotheses} \longrightarrow \text{Experiment} \longrightarrow \text{Evidence} \longrightarrow \text{Narrow Scope} \longrightarrow \text{Root Cause} \longrightarrow \text{Fix} \longrightarrow \text{Regression}$$

1. Provision the workspace:
   ```bash
   make provision
   ```
2. Formulate 3–5 hypotheses explaining why serial output ceased after decompression.
3. Design and execute a discriminating experiment using **`earlycon=pl011,0x09000000`** to make early kernel execution visible (capture with `make capture` after repairing your candidate manifest).
4. Capture and inspect the resulting log output to determine whether the kernel actually died, or whether output was misrouted.
5. Identify the root cause, author the repaired candidate, and verify regression recovery: boot the corrected system to an interactive shell in QEMU (`make capture && make check`).

## 2. Candidate Format

Your candidate is the **data-only launch manifest** at `challenge/build/candidate_launch_manifest.conf`:

```text
MACHINE=virt,highmem=off,gic-version=2
CPU=cortex-a7
MEM=512M
SMP=1
NOGRAPHIC=true
BOOTARGS=console=ttyS0,115200 rdinit=/init
```

Declarative `KEY=value` only — one definition per key, no shell, no substitution. The trusted runner derives the real `qemu-system-arm` command line from these values, records it, and executes exactly it, so what you declare is what gets run and graded.

## 3. Assessment Conditions (AI-Free)

> [!IMPORTANT]
> - **AI-Free Mode**: You must articulate hypotheses and analyze boot logs independently without AI code generation.
> - **Assessment Integrity**: You must NOT inspect grading reference solutions or hidden test fixtures until your attempt is submitted and scored. The exact defect values are hidden.
> - **Observable Evidence**: Your submission must provide the discriminating log captured with `earlycon` and the final working boot log reaching real BusyBox userspace.

## 4. Commands

```bash
make provision
make capture
make check
```
