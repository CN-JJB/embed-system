# P3-M05 Challenge — Availability / Resource-Description Fault

**AI policy: AI-Free (first scored attempt).** Official upstream documentation,
the Devicetree Specification v0.4, the Linux kernel source and the QEMU source
are all permitted. An AI assistant may not be used to produce the diagnosis or
the repair.

**Time:** ~25 min.

---

## 1. Situation

`challenge/fixtures/starter_virt.dtb` is a device tree blob that QEMU's `virt`
machine would accept and hand to a kernel. It parses cleanly, its structure is
sound, and it contains every node you would expect to find.

It is nevertheless **not** the tree the canonical Phase 3 platform should boot
with. One resource-description fact in it is wrong.

The symptom on a real boot is exactly the kind of thing you met in P3-M04: the
kernel starts, `earlycon` produces output, and then the system does not come up
the way the canonical platform does.

---

## 2. Your task

Produce a repaired device tree blob at `challenge/build/candidate.dtb` and a
short written diagnosis.

```bash
make provision          # stages the opaque starter artifact as your candidate
# ... your analysis and repair ...
make check              # learner-safe format/structure self-check
```

You may repair the tree with whatever tool is available:

* real `dtc` (`dtc -I dtb -O dts ...`, edit, `dtc -I dts -O dtb ...`);
* the module's own `scripts/fdt_patch.py`, which performs the same bounded edits
  on the parsed tree and re-serialises a canonical-layout blob.

Both are legitimate. What is *not* legitimate is guessing a value: your
diagnosis must say where the correct value comes from.

---

## 3. What you must submit

1. `challenge/build/candidate.dtb` — the repaired blob.
2. `challenge/build/DIAGNOSIS.md` — a written record containing:
   * **Symptom** — what you observe, in your own words;
   * **3–5 hypotheses** — independently generated, not copied from any worked
     example;
   * **Experiment** — the exact commands you ran;
   * **Evidence** — the exact output that discriminated between hypotheses
     (Observation / Interpretation / Non-Proof kept separate);
   * **Narrow scope** — what you ruled out and why;
   * **Root cause** — the mechanism, stated in terms of device tree semantics;
   * **Fix** — what you changed, and the command that performed it;
   * **Regression** — how you re-verified the repaired tree;
   * **Non-proof** — at least one thing your evidence does **not** establish.

The full diagnostic chain is required:

```text
Symptom → Own Description → 3–5 Hypotheses → Experiment → Evidence
→ Narrow Scope → Root Cause → Fix → Regression
```

---

## 4. Marking

| Weight | Criterion |
|---:|---|
| 45% | The repaired tree satisfies the canonical QEMU `virt` resource contract, verified semantically (not by string matching). |
| 25% | The diagnosis identifies the correct mechanism and the correct node/property. |
| 20% | The evidence presented actually discriminates between the hypotheses. |
| 10% | The non-proof statement is correct and specific. |

A repair that produces a *structurally invalid* blob, or that "fixes" the wrong
node, does not score. A diagnosis that reaches the right conclusion from a
fabricated observation does not score.

---

## 5. Bounded hints (AI-Hint level — use only if stuck)

<details>
<summary>Hint 1 — where to look</summary>

The tree has 57 nodes. You do not need to inspect all of them. Compare the
starter artifact against the tree you dumped in Lab 5.1, node by node, using a
*semantic* comparison rather than a textual one.

</details>

<details>
<summary>Hint 2 — what kind of fact</summary>

The defect is in a **resource-description property**, not in `compatible`, not
in a node name, and not in the tree structure. Ask yourself which properties in
this tree describe *where* hardware lives or *which* interrupt it raises.

</details>

<details>
<summary>Hint 3 — the reasoning step people skip</summary>

A property value is only meaningful together with the cell rules of the node
that *owns* the addressing context. Re-read `#address-cells` / `#size-cells`
along the path from the root to the node you are examining, and `#interrupt-cells`
on the interrupt controller. A value can be "a number that looks fine" and still
decode to the wrong resource.

</details>
