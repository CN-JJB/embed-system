# P3-M06 Challenge — Target Configuration Fault

**AI policy: AI-Free (first scored attempt).** Official Buildroot documentation
and source, the Linux kernel documentation, and the QEMU documentation are
permitted. No AI assistance for the diagnosis or the repair.

**Time:** ~25 min.

---

## 1. Situation

`challenge/fixtures/starter.conf` is a Buildroot configuration fragment in the
same `KEY=value` / `# KEY is not set` form Buildroot itself uses for defconfigs.
It is well formed: every symbol it names exists in the real Buildroot 2026.05.2
source tree, no symbol is defined twice, and there is no shell content smuggled
into any value.

It nevertheless does **not** describe the canonical Phase 3 appliance. One
target-level fact is wrong, and it is the kind of fact that decides whether the
generated root filesystem can run the userspace the rest of Phase 3 built.

---

## 2. Your task

Produce a repaired fragment at `challenge/build/candidate.conf` plus a written
diagnosis.

```bash
make provision          # stages the opaque starter fragment as your candidate
# ... your analysis and repair ...
make check              # learner-safe format self-check
```

Repair it by editing the fragment — this is a data artifact, not a script, and
the validator will reject anything that is not a plain configuration
declaration.

---

## 3. What you must submit

1. `challenge/build/candidate.conf` — the repaired fragment.
2. `challenge/build/DIAGNOSIS.md` — the full chain:

```text
Symptom → Own Description → 3–5 Hypotheses → Experiment → Evidence
→ Narrow Scope → Root Cause → Fix → Regression
```

with Observation / Interpretation / Non-Proof kept separate, and at least one
explicit statement of what your evidence does **not** prove.

Your diagnosis must cite **where in the real Buildroot source tree** the
relationship you are relying on is defined (file and, where practical, line).
"Because the reference file says so" is not a justification.

---

## 4. Marking

| Weight | Criterion |
|---:|---|
| 45% | The repaired fragment satisfies the canonical Buildroot contract, verified semantically. |
| 25% | The diagnosis names the correct symbol and the mechanism it controls. |
| 20% | The evidence presented actually discriminates between the hypotheses. |
| 10% | The non-proof statement is correct and specific. |

A fragment that merely *mentions* the right symbol in a comment does not score.
A diagnosis that reaches the right conclusion from a fabricated observation does
not score.

---

## 5. Bounded hints (AI-Hint level — use only if stuck)

<details>
<summary>Hint 1 — where the defect lives</summary>

The defect is in the **target description**, not in the kernel, the image
formats, or the overlay. Ask what determines the ABI every binary in the rootfs
is compiled for.

</details>

<details>
<summary>Hint 2 — read the definition, not a summary</summary>

The symbol you need is declared in `arch/Config.in.arm`. Read the whole
`choice` block it belongs to, including its `depends on` line, and compare it
against what `BR2_cortex_a7` selects.

</details>

<details>
<summary>Hint 3 — the consequence</summary>

The Phase 3 userspace was built for one floating-point ABI. If the rootfs is
built for the other, the loader and every binary disagree — the failure is a
runtime one, and no amount of "the build succeeded" changes it.

</details>
