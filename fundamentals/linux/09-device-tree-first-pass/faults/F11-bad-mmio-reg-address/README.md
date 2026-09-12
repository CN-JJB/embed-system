# F11 — Bad MMIO Resource Address (`reg`)

**Family:** Device Tree resource mapping · **Introduced:** P3-M05 ·
**Gate competency:** Phase 3 Final Gate Part C (hardware description binding)

> Worked **tutorial** fault. Hypotheses are written out deliberately; scored
> material does not pre-write them.

---

## 1. Mechanism

`reg` is not "an address". It is a **cell array interpreted under the addressing
rules of the node's parent**:

```text
reg = <address(#address-cells of parent)  size(#size-cells of parent)>
```

Every failure mode below is a *description* failure. The hardware did not move.

| Defect | Structural check | Semantic contract |
|---|---|---|
| wrong cell count | FAIL | FAIL |
| right cell count, wrong base address | PASS | FAIL |
| right base, silently overlapping another window | PASS | FAIL |
| `reg` present but on the wrong node | PASS | FAIL |

The third row is the interesting one: every number is a valid number, and the
node still describes hardware that does not exist at that address.

---

## 2. Reproduce

```bash
# (a) well-formed but wrong: 4 cells, base moved
python3 scripts/fdt_patch.py \
    --in  fixtures/qemu-virt.dtb \
    --out build/f11_wrong_base.dtb \
    --set-cells "/pl031@9010000" reg 0x00 0x09020000 0x00 0x1000

# (b) malformed: 3 cells under a 2+2 parent
python3 scripts/fdt_patch.py \
    --in  fixtures/qemu-virt.dtb \
    --out build/f11_bad_cells.dtb \
    --set-cells "/pl031@9010000" reg 0x00 0x09010000 0x00

python3 scripts/dt_structural_check.py build/f11_wrong_base.dtb   # PASS
python3 scripts/validate_dt_semantics.py build/f11_wrong_base.dtb # FAIL
python3 scripts/dt_structural_check.py build/f11_bad_cells.dtb    # FAIL
```

---

## 3. Diagnostic chain

### Symptom

```text
EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED
The system boots and the console works. One peripheral behaves inconsistently:
probe reports a resource conflict, or the driver maps a window that does not
contain its own registers. Nothing about the boot suggests a device tree problem.
```

This is deliberately **not** a spectacular crash. A crash would let you find the
fault by looking at the panic; the intended competency is *resource-description
diagnosis*.

### Own description

The kernel is alive and the console path is healthy. A single peripheral's
resource description is inconsistent with the machine QEMU presents.

### 3–5 hypotheses

1. The peripheral's driver is missing or was not compiled in.
2. The peripheral's node is marked unavailable.
3. The node's `reg` describes a window that is not where the device is.
4. The node's `reg` decodes under different cell rules than assumed, so the
   *interpreted* address differs from the intended one.
5. The blob that booted is not the blob that was edited.

### Experiment

```bash
# What does the tree say, interpreted correctly?
python3 scripts/validate_dt_semantics.py build/f11_wrong_base.dtb

# What are the addressing rules along the path?
python3 scripts/fdtlib_min.py build/f11_wrong_base.dtb --path "/"
python3 scripts/fdtlib_min.py build/f11_wrong_base.dtb --path "/pl031@9010000"

# What does the hardware model say the window should be?
# QEMU is the authority for the machine it presents:
qemu-system-arm -machine virt,dumpdtb=build/authority.dtb,highmem=off,gic-version=2 \
    -cpu cortex-a7 -m 512M -smp 1
python3 scripts/fdtlib_min.py build/authority.dtb --path "/pl031@9010000"
```

### Evidence

```text
[FAIL] rtc.reg.entries -- /pl031@9010000 reg decodes to [(151126016, 4096)]
       under parent / #address-cells=2/#size-cells=2;
       expected [(151060480, 4096)]
[FAIL] mmio.no-overlap -- /pl031@9010000 [0x9020000,0x9021000) overlaps
       /fw-cfg@9020000 [0x9020000,0x9020018)
```

Note the *second* line. The tree contains no string saying "conflict"; the
conflict exists only in the interpreted address space, and only a validator that
decodes `reg` under the parent's cell rules can see it.

### Narrow scope

* The node exists, is reachable, and has no `status` — hypotheses 1 and 2 are
  weakened (they would leave no node-specific resource error).
* The `compatible` string is intact, so the *identification* is right; only the
  *resource* is wrong.
* Re-dumping the machine produces the canonical window — the hardware model did
  not change; hypothesis 3 survives.
* The interpretation used the parent's declared cells (2+2 = 4 cells), and the
  value has exactly 4 cells, so this is not a cell-count misunderstanding —
  hypothesis 4 is out for variant (a), and is *precisely* the surviving
  hypothesis for variant (b).

### Root cause

The node's `reg` does not describe the window the machine presents. Two distinct
sub-mechanisms are covered:

* **variant (a):** a valid-looking address that is simply not the device's
  address — and which silently overlaps another device's window.
* **variant (b):** a cell array whose length contradicts the parent's
  `#address-cells`/`#size-cells`, so there is no correct interpretation at all.

### Fix

Restore the value the hardware model presents, under the correct cell rules:

```bash
python3 scripts/fdt_patch.py \
    --in  fixtures/qemu-virt.dtb \
    --out build/f11_fixed.dtb \
    --set-cells "/pl031@9010000" reg 0x00 0x09010000 0x00 0x1000

python3 scripts/validate_dt_semantics.py build/f11_fixed.dtb --quiet
# === DT SEMANTIC CONTRACT: PASS ===
```

### Regression

* structural check PASS,
* semantic contract PASS,
* where a kernel is available: the peripheral probes without a resource conflict
  and its driver reads the registers it expects.

---

## 4. Why "fix it until the crash goes away" is the wrong lesson

If the mutation were chosen to guarantee a kernel panic, the learner would find
it by reading the panic. The mutation here is chosen so that the *only* reliable
route is:

```text
read the description
→ apply the parent's addressing rules
→ compare the decoded resource against the machine the hardware model presents
```

That is the transferable skill. It is also the skill the Module Gate measures.

---

## 5. Non-proof to keep in mind

A `reg` that matches the canonical machine is a *description* that matches.
It is still not proof that the kernel mapped it, that the driver's `ioremap`
succeeded, or that any register access happened. Those are Phase 4 concerns, and
they are out of scope here.
