# Lab 5.3 — Bounded, Reversible Modification

**Time:** ~45 min. **Prerequisite:** Lab 5.2.

---

## 1. Goal

Change **one** bounded property, rebuild the blob, and observe the effect. The
point is not to break the platform — it is to learn to separate two very
different things:

* what changes because the **hardware description** changed;
* what would change because a **driver** behaved differently.

A modification is useful only if it produces a *diagnosable* difference. A
change that simply destroys the console produces one observation ("nothing") and
teaches nothing about resource description.

---

## 2. Exercise A — availability (`status`)

The `status` property answers "is this hardware *available*?" independently of
whether it is *described*. Absent `status` means available.

```bash
python3 scripts/fdt_patch.py \
    --in  fixtures/qemu-virt.dtb \
    --out build/status_disabled.dtb \
    --set-string "/pl031@9010000" status disabled
```

Now compare the two trees semantically:

```bash
python3 scripts/dt_roundtrip_check.py fixtures/qemu-virt.dtb build/status_disabled.dtb
```

The tool reports the single property that differs. That is the *whole* change:
one property, one node, nothing else.

Questions to answer before you boot anything:

1. Which node did you change, and is it the console?
2. If you boot this tree, will QEMU still model the GPIO controller? (Think
   about what QEMU is, and what the blob is.)
3. Will the kernel still *create* a device for that node?
4. What evidence would let you distinguish "the device is absent" from "the
   device is present but not enabled"?

> **Why the GPIO and not the UART?** Because changing the console's availability
> destroys the channel you need to observe anything. Choosing a modification
> that *preserves your evidence channel* is part of the engineering skill this
> lab teaches. Fault F10 deliberately uses the console, because *that* fault is
> about recognising a destroyed channel.

---

## 3. Exercise B — a resource value (`reg`)

Move a device's register window to a different address, keeping the cell count
valid:

```bash
python3 scripts/fdt_patch.py \
    --in  fixtures/qemu-virt.dtb \
    --out build/reg_moved.dtb \
    --set-cells "/pl031@9010000" reg 0x00 0x09020000 0x00 0x1000
```

Then run the semantic validator:

```bash
python3 scripts/validate_dt_semantics.py build/reg_moved.dtb
```

Read the failure carefully. The node's *shape* is fine — 4 cells, matching the
root's 2+2 rule. What fails is the relationship between this window and another
device's window. That is what "resource description" means: the tree is a
*map*, and a map with two objects on the same square is wrong even if every
coordinate is a valid number.

---

## 4. Exercise C — the cell-count trap

Change only the *number of cells*:

```bash
python3 scripts/fdt_patch.py \
    --in  fixtures/qemu-virt.dtb \
    --out build/reg_short.dtb \
    --set-cells "/pl031@9010000" reg 0x00 0x09010000 0x00
```

This time the *structural* checker also fails:

```bash
python3 scripts/dt_structural_check.py build/reg_short.dtb
```

Compare the two failure modes:

| Modification | Structural check | Semantic contract |
|---|---|---|
| `status = "disabled"` | PASS | FAIL (`status`) |
| wrong base address | PASS | FAIL (`reg`) |
| wrong cell count | **FAIL** | FAIL (`reg`) |

The first two are *well-formed lies*. The third is a malformed value. Only a
validator that understands addressing rules can catch all three; a validator
that looks for strings catches none of them.

---

## 5. Booting a modified tree (optional)

If you have the Phase 3 kernel and initramfs:

```bash
bash scripts/run_qemu_dtb_boot.sh build/status_disabled.dtb \
    /path/to/zImage /path/to/rootfs.cpio.gz \
    build/status_disabled.log build/status_disabled.argv
```

> `EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED`
> The observations below describe what the *mechanism* predicts. They were not
> captured on this authoring host, which has no ARM kernel build available.
> Replace them with your own capture before using them as evidence.

Expected, from the mechanism:

* QEMU still emulates the GPIO controller. The blob changed; the machine did
  not. If you believe otherwise, you have confused the description with the
  hardware.
* The kernel logs the device tree it consumed, and the node you disabled does
  not produce a bound device — the corresponding entry under
  `/sys/bus/platform/devices` (or `/sys/firmware/devicetree/base`) reflects the
  new `status`.
* **The absence of one runtime device is not evidence that the hardware
  vanished.** It is evidence that the *description* changed.

If you boot the `reg_moved.dtb` variant, expect a resource conflict between the
two overlapping windows to be reported during driver probe — again, because the
description is wrong, not because the hardware moved.

---

## 6. Checkpoint

1. You produced at least one well-formed-but-semantically-wrong tree and one
   malformed tree, and can state which checker catches which.
2. You can state, for each modification, whether the *hardware* changed.
3. You can explain why Exercise A deliberately avoids the console node.

**Non-proof.** Observing a runtime difference after editing a blob proves that
the kernel consumed *a* device tree. It does not prove the kernel consumed
*your* blob unless the boot is bound to it (see Lab 5.4).
