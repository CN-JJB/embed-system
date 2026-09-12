# P3-M05 Module Gate — Device Tree Resource Diagnosis (AI-Free)

**AI policy: AI-Free (strict).** Official Devicetree Specification v0.4, Linux
kernel documentation and source, QEMU documentation and source, and `dtc`
documentation are permitted. No AI assistance for the diagnosis, the repair, or
the written reasoning.

**Time:** ~40 min.

**Prerequisite:** you have completed Labs 5.1–5.4 and the Challenge.

---

## 1. Situation

`gate/fixtures/starter_virt.dtb` is a device tree blob for the canonical Phase 3
platform. It is **structurally sound**: it parses, its node and property names
are well formed, its sibling and property names are unique, every phandle
reference resolves, and every `reg` and `interrupts` value decodes without a
cell-count error under the rules of the tree that declares it.

It is nevertheless **not a correct description of the hardware the canonical
QEMU `virt` machine presents**. More than one resource fact in it is wrong.

```text
EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED
A boot with this tree is expected to leave the console output path functional
while a peripheral resource is misdescribed, so the failure is not a clean
"nothing happens" symptom.  You must therefore reason from the *description*
and from discriminating evidence, not from a single visible failure.
```

---

## 2. Your task

1. Repair the tree so that it describes the canonical `virt` hardware, and
   write it to `gate/build/candidate.dtb`.
2. Write `gate/build/DIAGNOSIS.md`.
3. If you have the Phase 3 kernel and initramfs available, capture runtime
   evidence and bind it to your candidate:

   ```bash
   make capture KERNEL=/path/to/zImage INITRD=/path/to/rootfs.cpio.gz
   ```

   The capture records the executed QEMU argv as provenance and a bounded,
   read-only probe of `/sys/firmware/devicetree/base`; the binding is verified
   against *your* candidate blob, not against a canonical substitute.

---

## 3. Required reasoning (this is what is actually graded)

Your `DIAGNOSIS.md` must contain the full chain:

```text
Symptom → Own Description → 3–5 Hypotheses → Experiment → Evidence
→ Narrow Scope → Root Cause → Fix → Regression
```

and must additionally answer, explicitly:

1. **Cell context.** For every property you changed, state the node that owns
   the addressing context and its `#address-cells` / `#size-cells` (or
   `#interrupt-cells`), and show how the cell array decodes under that context.
2. **Provenance of the correct value.** State where the correct value comes
   from — the QEMU hardware model, the kernel binding, or a runtime
   observation. "It matches the reference file" is **not** an acceptable
   justification; the reference file is a convenience, not an authority.
3. **Representation.** Distinguish the three representations of the same fact:
   the source form, the compiled binary form, and the runtime form the kernel
   exposes. Give one concrete example of a fact that is *easy to read
   correctly* in one representation and *easy to misread* in another.
4. **Non-proof.** State at least two things your evidence does **not**
   establish. At least one must concern the difference between "the device tree
   describes the hardware" and "the kernel actually used the resource".

---

## 4. Marking

| Weight | Criterion |
|---:|---|
| 30% | Both resource facts are repaired correctly, verified semantically. |
| 25% | Cell-context reasoning is correct for each changed property. |
| 20% | Correct-value provenance is argued from the hardware model / binding, not from the reference file. |
| 15% | Representation distinction is correct and concrete. |
| 10% | Non-proof statements are correct, specific, and non-trivial. |

Pass mark: **75%**, with the semantic-repair component at **≥ 60%**.

---

## 5. Evidence boundary you must respect in your write-up

* A tree that parses is not a tree that is correct.
* A value that matches the canonical reference is not a value that was
  *justified*.
* Decompiling and recompiling a tree is not proof that a kernel used the
  resource at runtime.
* A captured console log is not evidence about *your* artifact unless it is
  bound to it (executed argv + artifact identity).
* QEMU virtual-platform execution is not physical-board bring-up evidence.
