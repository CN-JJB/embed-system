# F10 — Device Tree Node Disabled (`status = "disabled"`)

**Family:** Device Tree availability · **Introduced:** P3-M05 ·
**Gate competency:** Phase 3 Final Gate Part C (DT resource representation)

> This is a **worked tutorial fault**. The hypotheses are written out because
> the purpose here is to teach the diagnostic method. Scored material
> (Challenge, Module Gate) never pre-writes hypotheses.

---

## 1. Mechanism

`status` is the device tree's *availability* switch. It is independent of
whether the node is described:

| `status` value | Effective meaning |
|---|---|
| absent | available (the specification default) |
| `"okay"` / `"ok"` | available |
| `"disabled"` | described, but not available |
| `"reserved"`, `"fail"`, `"fail-sss"` | not available |

The kernel does not delete the node and the hardware is not removed. The
*description* changes, and device creation follows the description.

---

## 2. Reproduce

```bash
python3 scripts/fdt_patch.py \
    --in  fixtures/qemu-virt.dtb \
    --out build/f10_console_disabled.dtb \
    --set-string "/pl011@9000000" status disabled

python3 scripts/dt_roundtrip_check.py fixtures/qemu-virt.dtb build/f10_console_disabled.dtb
```

The comparison shows exactly one difference: a `status` property added to the
console UART node.

---

## 3. Diagnostic chain

### Symptom

```text
EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED
earlycon=pl011,0x09000000 prints the early banner and the kernel's early boot
messages. After the point where the normal console would take over, the terminal
goes quiet and the system never reaches a shell.
```

### Own description

Early, polled output works. Output through the normal serial console does not.
The failure is at the *handoff from earlycon to the registered console*, not at
kernel entry.

### 3–5 hypotheses

1. The kernel command line names the wrong console device.
2. The PL011 driver was not compiled in.
3. The UART node is present but marked unavailable, so no device is created for
   it and the console never registers.
4. The QEMU UART was not created because the machine options changed.
5. The blob that booted is not the blob that was edited.

### Experiment

```bash
# What does the tree actually say about the console node?
python3 scripts/fdtlib_min.py build/f10_console_disabled.dtb --path "/pl011@9000000"

# Is the machine still modelling the UART?  Ask QEMU, not the blob.
qemu-system-arm -machine virt,highmem=off,gic-version=2 -cpu cortex-a7 -m 512M \
    -smp 1 -nographic -dtb build/f10_console_disabled.dtb \
    -kernel zImage -initrd rootfs.cpio.gz \
    -append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init"

# Compare against the known-good tree.
python3 scripts/dt_roundtrip_check.py fixtures/qemu-virt.dtb build/f10_console_disabled.dtb
```

### Evidence

```text
[PATCH] set-string /pl011@9000000 status = 'disabled'
REJECT: the round-tripped tree differs semantically (…)
  +  PROP status = 64697361626c656400        # "disabled\0"
```

`64 69 73 61 62 6c 65 64 00` is `"disabled"` followed by the NUL terminator
that every string property carries.

### Narrow scope

* The command line is unchanged and still names `ttyAMA0` — hypothesis 1 is out.
* The kernel image is unchanged; the driver is compiled in — hypothesis 2 is out.
* QEMU's argv still creates the PL011; `dumpdtb` with the same options produces
  a node for it — hypothesis 4 is out.
* The only difference between the working and failing boots is the `-dtb`
  argument — hypothesis 5 is out, and hypothesis 3 remains.

### Root cause

The blob describes the PL011 UART as unavailable. The kernel therefore does not
create a platform device for it, the `amba-pl011` driver never probes, and
`console=ttyAMA0` has nothing to attach to. `earlycon` keeps working because it
does not go through the driver model at all — it writes the UART registers
directly from a fixed physical address.

### Fix

```bash
python3 scripts/fdt_patch.py \
    --in  fixtures/qemu-virt.dtb \
    --out build/f10_fixed.dtb \
    --delete "/pl011@9000000" status
# or, equivalently, --set-string "/pl011@9000000" status okay
```

### Regression

```bash
python3 scripts/validate_dt_semantics.py build/f10_fixed.dtb --quiet
# === DT SEMANTIC CONTRACT: PASS ===
```

and, where a kernel is available, a boot that reaches the shell with normal
(non-earlycon) console output.

---

## 4. The point people miss

> **QEMU still models the virtual hardware. The device tree availability
> changed. The runtime enumeration changed. None of these three facts implies
> the others.**

`status = "disabled"` does not remove a device from the machine. It removes it
from the *description of the machine*. If your conclusion is "the UART is gone",
you have confused the map with the territory — which is the entire reason this
fault family exists.

---

## 5. Transfer to the Final Gate

The Gate uses an unfamiliar variant: a different node, a different resource
property, and a combination that is not a replay of this worked example. The
method transfers; the answer does not.
