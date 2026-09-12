# P3-M05 — Device Tree First Pass: Hardware Description, DTC & Resource Inspection

**Time budget:** 3.5 h MUST (+ ≤ 1.0 h SHOULD)
**Prerequisites:** P3-M01 (toolchain/target artifacts), P3-M02 (kernel build &
boot), P3-M04 (QEMU bring-up, bootargs, console)
**Platform:** ARMv7-A / Cortex-A7 on the canonical QEMU `virt` machine

---

## 1. Mission

Phase 2 hardcoded peripheral addresses and interrupt numbers in C macros and
linker scripts. A modern ARM Linux kernel does not know any of that: it is told,
at boot, by a **device tree**. Your job in this module is to be able to read
that description, reason about it correctly, change it deliberately, and connect
it to what a running kernel exposes.

```text
QEMU virtual hardware
  → generated DTB
  → decompiled DTS
  → nodes / properties / resources
  → Linux boot consumption
  → runtime representation under /sys/firmware/devicetree/base
```

A device tree **describes** devices and resources. It does not implement driver
behaviour. Keeping that line sharp is the whole module.

---

## 2. What you will be able to do

* Explain the difference between `.dts`, `.dtsi` and `.dtb`, and between the
  *source*, *compiled* and *runtime* representations of the same fact.
* Read a node: name, unit address, properties, children.
* Interpret `reg` correctly — which means **under the addressing rules of the
  parent**, using `#address-cells` / `#size-cells`.
* Interpret `interrupts` correctly — which means **under the interrupt
  controller's `#interrupt-cells`**, reached through an inherited
  `interrupt-parent` phandle.
* Explain `compatible` as a matching key, not executable code.
* Explain `status` and the difference between *described* and *available*.
* Decompile and recompile a real QEMU blob with `dtc`, and prove the round trip
  is semantically lossless.
* Correlate a tree with a running kernel under `/sys/firmware/devicetree/base`,
  including reading binary cell properties correctly.
* Diagnose an availability fault (F10) and a resource-description fault (F11)
  with the full evidence chain.

**Explicitly out of scope** (Phase 4 and beyond): platform-driver
implementation, kernel modules, `probe()`/`remove()`, subsystem matching, deep
OF internals, YAML binding authoring, physical-board DT bring-up.

---

## 3. Canonical platform contract (do not silently change)

| Component | Canonical | Identity |
|---|---|---|
| QEMU | **11.1.1** | tag `v11.1.1`, peeled commit `c3d48b7d1e89604920e5b81b91140c2ad39a1943` |
| Machine | `virt,highmem=off,gic-version=2` | CPU `cortex-a7`, `-m 512M`, `-smp 1`, `-nographic` |
| Linux | **6.18.50 LTS** | tag `v6.18.50`, peeled commit `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7` |
| DTC | **v1.7.0** | tag `v1.7.0`, peeled commit `039a99414e778332d8f9c04cbd3072e1dcc62798` |
| Devicetree Spec | **v0.4** | tag `v0.4`, peeled commit `112f53cc57e5931f1503dfcaa1644caf15362c30` |

Canonical and actual-host runtimes are **separate evidence dimensions**. Say
which one you used; never substitute one for the other silently.

---

## 4. Layout

```text
09-device-tree-first-pass/
  README.md                    this file
  SOURCE_LEDGER.md             exact pins, what was executed, evidence status
  Makefile                     learner-safe entry points
  labs/01-dump-qemu-virt-dtb/       Lab 5.1  (~30 min)
  labs/02-decompile-inspect-recompile/  Lab 5.2  (~50 min)
  labs/03-bounded-safe-modification/    Lab 5.3  (~45 min)
  labs/04-runtime-dt-correlation/       Lab 5.4  (~45 min)
  faults/F10-disabled-dt-node/      worked tutorial fault
  faults/F11-bad-mmio-reg-address/  worked tutorial fault
  challenge/                   AI-Free Challenge (practiced family)
  gate/                        AI-Free Module Gate (unfamiliar variant)
  fixtures/                    real QEMU-generated DTB + real dtc decompilation
  scripts/                     learner-facing tooling
  reviewer (directory)         reviewer-only oracle, seeds and mutation suites;
                               never referenced by any learner workflow
```

---

## 5. The mental model in one page

### 5.1 Source, binary, runtime

| Representation | What it is | Where it lives |
|---|---|---|
| `.dts` / `.dtsi` | human-authored source | your repository |
| `.dtb` | flattened binary token stream | passed to the kernel at boot |
| runtime tree | kernel's unflattened node objects | `/sys/firmware/devicetree/base` |

The sysfs projection is mechanical: node → directory, property → file,
property value → raw bytes. String properties are NUL-terminated; cell
properties are big-endian 32-bit words. **Neither is "plain text".**

### 5.2 Properties are only meaningful in context

```text
reg        = <address  size>        interpreted with DIRECT PARENT #address-cells/#size-cells (NOT inherited; defaults to 2/1 if absent)
interrupts = <specifier ...>        interpreted with the INTERRUPT PARENT's #interrupt-cells (interrupt-parent IS inherited)
compatible = string list            a matching key the kernel looks up in a table
status     = string                 availability, not existence
phandle    = <u32>                  a node's handle; other properties reference it
```

> [!IMPORTANT]
> **Inheritance Rule Distinction**:
> - `#address-cells` and `#size-cells` are **never inherited** from ancestors (Devicetree Specification v0.4 §2.3.5). A child's `reg` is decoded using only its *direct parent's* properties. If the parent omits them, the client decoder uses specification defaults: `#address-cells = <2>` and `#size-cells = <1>`, regardless of what grandparents specify.
> - `interrupt-parent` **is inherited**: if a node omits `interrupt-parent`, it inherits the phandle of its nearest ancestor.

The single most common real-world device tree bug is a `reg` that is
"a number that looks fine" and decodes to the wrong resource. The second is an
`interrupts` array whose length contradicts `#interrupt-cells`.

### 5.3 What the kernel actually does with it

From Linux 6.18.50 `Documentation/devicetree/usage-model.rst`:

* on ARM, `setup_arch()` (`arch/arm/kernel/setup.c`) calls `setup_machine_fdt()`
  (`arch/arm/kernel/devtree.c`), which picks the best `machine_desc`
  (`arch/arm/include/asm/mach/arch.h`) by matching the **root** `compatible`;
* `unflatten_device_tree()` converts the blob into the runtime representation;
* `.init_machine()` populates the Linux device model from the tree instead of
  from static board structures.

The PL011 binding (`Documentation/devicetree/bindings/serial/pl011.yaml`) is the
concrete example used throughout: required properties are `compatible`, `reg`
and `interrupts`; `compatible` is exactly
`["arm,pl011", "arm,primecell"]`; `clock-names` is
`["uartclk", "apb_pclk"]`.

---

## 6. Labs

| Lab | Title | Time | Deliverable |
|---|---|---:|---|
| 5.1 | Dump the QEMU `virt` device tree | 30 min | real DTB + provenance |
| 5.2 | Decompile, inspect, recompile | 50 min | lossless round trip + node decode table |
| 5.3 | Bounded, reversible modification | 45 min | one well-formed-but-wrong tree, one malformed tree |
| 5.4 | Runtime device tree correlation | 45 min | bound runtime capture + correlation table |

---

## 7. Controlled faults

| ID | Fault | Family | Detection |
|---|---|---|---|
| **F10** | node disabled via `status` | availability | semantic contract (`status`) |
| **F11** | wrong `reg` resource | resource mapping | semantic contract (`reg`, overlap) |

Both are worked tutorials. The scored Challenge and Module Gate use variants.

---

## 8. Assessment

Both the Challenge and the Module Gate are **AI-Free** on the first attempt.
Official upstream sources are permitted; an AI assistant is not.

* `challenge/README.md` — an opaque, structurally sound but non-canonical tree;
  repair it and write the diagnostic chain.
* `gate/README.md` — an unfamiliar combined variant with extra required
  reasoning (cell context, provenance of the correct value, representation
  distinction, non-proof).

Both submit a repaired `.dtb` and are graded by a **semantic** oracle, not by
string matching. The grading oracle is reviewer-only; learner workflows never invoke
it.

---

## 9. Verification

```bash
make check                     # learner-safe: docs, fixtures, tooling, provisioning
make roundtrip                 # real dtc dtb -> dts -> dtb, semantically verified
make dump-dtb                  # regenerate the real QEMU DTB with provenance
make gate-provision            # stage the Gate's opaque starter artifact
make challenge-provision       # stage the Challenge's opaque starter artifact
```

Runtime capture (needs the Phase 3 kernel and initramfs):

```bash
make capture KERNEL=/path/to/zImage INITRD=/path/to/rootfs.cpio.gz
```

Reviewer-only authoring regression (`make reviewer-check`) is never part of a
learner workflow.

---

## 10. Evidence boundary

* A DTB that parses is not a DTB that is correct.
* A `dtb → dts → dtb` round trip proves representational agreement, not hardware
  correctness.
* A captured boot proves the kernel accepted *a* blob; binding it to *your*
  blob requires executed-argv provenance and artifact identity.
* QEMU virtual-platform execution is not physical-board bring-up evidence.
* DTB generation, `dtc` round trip and DT artifact semantics are VERIFIED on the
  authoring host. Kernel boot and `/sys/firmware/devicetree/base` correlation are
  **UNVERIFIED** there. See `SOURCE_LEDGER.md` for the exact split.
