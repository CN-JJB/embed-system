# P3-M04 AI-Free Challenge — Silent Boot Failure Isolation

## 1. Challenge Briefing

You are provided with an appliance launch configuration that terminates in complete silence immediately after the decompressor output:
```text
Uncompressing Linux... done, booting the kernel.
(Terminal completely silent; system appears hung)
```

Your mission:
Apply the disciplined diagnostic loop:
$$\text{Symptom} \longrightarrow \text{Own Description} \longrightarrow \text{3–5 Hypotheses} \longrightarrow \text{Experiment} \longrightarrow \text{Evidence} \longrightarrow \text{Narrow Scope} \longrightarrow \text{Root Cause} \longrightarrow \text{Fix} \longrightarrow \text{Regression}$$

1. Formulate 3–5 hypotheses explaining why serial output ceased after decompression.
2. Design and execute a discriminating experiment using **`earlycon=pl011,0x09000000`** to make early kernel execution visible.
3. Capture and inspect the resulting log output to determine whether the kernel actually died, or whether output was misrouted.
4. Identify the root cause and implement the fix.
5. Verify regression recovery: boot the corrected system to an interactive shell in QEMU.

---

## 2. Assessment Conditions (AI-Free)

> [!IMPORTANT]
> - **AI-Free Mode**: You must articulate hypotheses and analyze boot logs independently without AI code generation.
> - **Assessment Integrity**: You must NOT inspect grading reference solutions or hidden test fixtures until your attempt is submitted and scored.
> - **Observable Evidence**: Your submission must provide the discriminating log captured with `earlycon` and the final working boot log reaching `/ # `.

---

## 3. Verification Command

```bash
make challenge-build
make check
```
