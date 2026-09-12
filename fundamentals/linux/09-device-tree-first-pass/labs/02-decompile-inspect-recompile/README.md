# Lab 5.2 — Decompile, Inspect, Recompile

**Time:** ~50 min. **Prerequisite:** Lab 5.1.

---

## 1. Why

A `.dtb` is a binary. To reason about it you need a human-readable view, and to
change it you need a path back to binary. That is the whole job of the Device
Tree Compiler:

```text
.dts  --(dtc -I dts -O dtb)-->  .dtb  --(dtc -I dtb -O dts)-->  .dts
```

The canonical curriculum baseline is **dtc v1.7.0** (tag `v1.7.0`, peeled
commit `039a99414e778332d8f9c04cbd3072e1dcc62798`) together with the
**Devicetree Specification v0.4** (tag `v0.4`, peeled commit
`112f53cc57e5931f1503dfcaa1644caf15362c30`).

---

## 2. Do it

```bash
bash scripts/dtc_roundtrip.sh fixtures/qemu-virt.dtb build/roundtrip
```

That performs `dtb → dts → dtb` and then proves the round trip is lossless.
If your host has no `dtc`, the module still gives you a semantic view:

```bash
python3 scripts/fdtlib_min.py fixtures/qemu-virt.dtb --dump --skip-props ""
python3 scripts/derive_sysfs_tree.py fixtures/qemu-virt.dtb --path "/pl011@9000000"
```

---

## 3. Read the real tree

`fixtures/qemu-virt.dts` is the real decompilation of the QEMU dump. The
sections below quote it verbatim.

### 3.1 Root: identity and the addressing context

```dts
/ {
        interrupt-parent = <0x8002>;
        model = "linux,dummy-virt";
        #size-cells = <0x02>;
        #address-cells = <0x02>;
        compatible = "linux,dummy-virt";
        ...
```

Three things to notice:

* `compatible` and `model` are **identification keys**, not executable code.
  The kernel matches them against a table. `Documentation/devicetree/usage-model.rst`
  (Linux 6.18.50) describes the mechanism precisely: on ARM, `setup_arch()` in
  `arch/arm/kernel/setup.c` calls `setup_machine_fdt()` in
  `arch/arm/kernel/devtree.c`, which searches the `machine_desc` table
  (`arch/arm/include/asm/mach/arch.h`) for the best match on the *root*
  `compatible` property.
* `#address-cells = <2>` and `#size-cells = <2>` are the **addressing rules for
  every direct child of the root**. Every `reg` directly under `/` is therefore
  `address(2 cells) size(2 cells)` = 4 cells. Note that `#address-cells` and
  `#size-cells` are **not inherited** from ancestors; if an intermediate bus node
  omits them, children default to `#address-cells = <2>` and `#size-cells = <1>`,
  rather than inheriting from the root.
* `interrupt-parent = <0x8002>` is a **phandle reference** that is *inherited*.
  A node with no `interrupt-parent` of its own uses the nearest ancestor's.

### 3.2 The console UART — the node everything else is checked against

```dts
pl011@9000000 {
        clock-names = "uartclk\0apb_pclk";
        clocks = <0x8000 0x8000>;
        interrupts = <0x00 0x01 0x04>;
        reg = <0x00 0x9000000 0x00 0x1000>;
        compatible = "arm,pl011\0arm,primecell";
};
```

Decode it, cell by cell, **using the parent's rules**:

| Property | Raw cells | Decoded |
|---|---|---|
| `reg` | `0x00 0x09000000 0x00 0x00001000` | base `0x09000000`, size `0x1000`, under root `#address-cells=2`/`#size-cells=2` |
| `interrupts` | `0x00 0x01 0x04` | GIC specifier: type `0` (SPI), number `1`, trigger `4` (level, active-high) |
| `compatible` | `"arm,pl011\0arm,primecell\0"` | a string *list*: `["arm,pl011", "arm,primecell"]` |
| `clock-names` | `"uartclk\0apb_pclk\0"` | `["uartclk", "apb_pclk"]` |

`interrupts` is **not self-describing**. Its meaning comes from the interrupt
controller it is attached to. Follow `interrupt-parent` from `/pl011@9000000`
up to the root (`<0x8002>`) and resolve that phandle:

### 3.3 The interrupt controller — where the specifier's shape is defined

```dts
intc@8000000 {
        phandle = <0x8002>;
        reg = <0x00 0x8000000 0x00 0x10000 0x00 0x8010000 0x00 0x10000>;
        compatible = "arm,cortex-a15-gic";
        ranges;
        #size-cells = <0x02>;
        #address-cells = <0x02>;
        interrupt-controller;
        #interrupt-cells = <0x03>;
        ...
};
```

* `#interrupt-cells = <3>` is what makes `<0 1 4>` a *complete* specifier and
  `<0 1>` an incomplete one.
* `reg` here has **two** entries (distributor and CPU interface) — 8 cells for
  two `(address, size)` pairs under the root's 2+2 rule.
* `phandle = <0x8002>` is the declaration; the root's `interrupt-parent` is the
  reference.

### 3.4 A memory node, a virtio device, and a CPU

```dts
memory@40000000 {
        reg = <0x00 0x40000000 0x00 0x20000000>;
        device_type = "memory";
};

virtio_mmio@a000000 {
        dma-coherent;
        interrupts = <0x00 0x10 0x01>;
        reg = <0x00 0xa000000 0x00 0x200>;
        compatible = "virtio,mmio";
};

cpus {
        #size-cells = <0x00>;
        #address-cells = <0x01>;
        cpu@0 {
                reg = <0x00>;
                compatible = "arm,cortex-a7";
                device_type = "cpu";
                ...
        };
};
```

* `memory@40000000`: `0x40000000 + 0x20000000` = 512 MiB, exactly the `-m 512M`
  you passed in Lab 5.1. This is a *resource description*: the kernel sizes
  physical memory from it.
* `cpus` **changes the addressing rules for its children**: `#address-cells=1`,
  `#size-cells=0`, so `cpu@0`'s `reg = <0x00>` is a single-cell address with no
  size. The same 4-cell value that is right under `/` would be *wrong* here.
* `virtio_mmio@a000000` is one of 32 identical windows. Only one is shown; the
  node name's unit address (`@a000000`) is documentation, and the `reg` is the
  authority. They must agree.

### 3.5 `chosen`

```dts
aliases {
        serial0 = "/pl011@9000000";
};

chosen {
        stdout-path = "/pl011@9000000";
        rng-seed = <...>;
        kaslr-seed = <...>;
};
```

`chosen` is not hardware. It carries boot-time *runtime configuration* — which
device the console should be, and entropy for the kernel. It is also the reason
your blob hashes differ between runs.

---

## 4. Prove the round trip

`scripts/dtc_roundtrip.sh` ends with a **semantic** comparison:

```text
[PASS] node hierarchy identical (57 node(s) each)
[PASS] property sets and values identical
[PASS] memory reservation block identical
=== ROUND-TRIP: SEMANTICALLY EQUIVALENT ===
```

Note what is *not* used as the proof:

* **not byte equality** — the rebuilt blob legitimately differs (layout,
  padding, string-block ordering);
* **not string presence** — a string in the file proves nothing about which
  node carries it, or whether the node is even reachable.

A tree is equivalent when the hierarchy, the property sets and the property
*values* are equivalent, with a documented exclusion list for properties that a
producer is allowed to randomise.

### 4.1 Why `dtc` prints warnings when you recompile a decompiled tree

You will see lines like:

```text
qemu-virt.dts:310.3-28: Warning (clocks_property): /pl011@9000000:clocks: cell 0 is not a phandle reference
qemu-virt.dts:267.4-31: Warning (gpios_property): /gpio-keys/poweroff:gpios: cell 0 is not a phandle reference
```

This is a property of the *decompiled source*, not a defect in the tree.
`dtc -O dts` renders every cross-reference as a **literal number**
(`clocks = <0x8000 0x8000>`) because the blob has no labels — labels exist only
in hand-written source. When `dtc` compiles a source that uses a literal number
where a phandle is expected, it cannot confirm that the cell really is a phandle
reference, so its `*_property` checks warn. The same tree written with a label
reference (`clocks = <&clk>;`) produces no such warning.

The warnings do not alter the emitted blob. That is exactly why the round trip
is proved **semantically** rather than by "the compiler printed nothing". If you
want to confirm this yourself:

```bash
dtc -I dts -O dtb build/roundtrip/qemu-virt.dts -o /tmp/x.dtb -Wno-clocks_property -Wno-gpios_property
cmp /tmp/x.dtb build/roundtrip/qemu-virt.rebuilt.dtb && echo "identical output"
```

---

## 5. Checkpoint

1. `bash scripts/dtc_roundtrip.sh fixtures/qemu-virt.dtb build/roundtrip` passes.
2. You can decode `reg = <0x00 0x9000000 0x00 0x1000>` under the root's cell
   rules *and* explain why the same four cells would be wrong under `/cpus`.
3. You can explain why `interrupts = <0x00 0x01 0x04>` needs
   `#interrupt-cells` from another node to be interpretable.
4. You can name the two properties that make the blob hash unstable.

**Non-proof.** A passing round trip proves the compiler and the decompiler agree
about the *representation*. It does not prove the tree describes the real
hardware, and it does not prove any kernel used it.
