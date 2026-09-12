# Lab 5.4 — Runtime Device Tree Correlation

**Time:** ~45 min. **Prerequisite:** Labs 5.1–5.3, and a bootable Phase 3
appliance (P3-M03/M04).

---

## 1. Why

Everything so far has been about a *file*. The competency that matters is
connecting that file to a *running system*. Linux exposes the tree it consumed
under:

```text
/sys/firmware/devicetree/base
```

The projection is direct and mechanical:

| Device tree | sysfs |
|---|---|
| node | directory |
| property | file |
| property value | file contents, raw bytes |

Two consequences follow immediately, and both are places people get hurt:

1. **Property files are binary.** A property holding cells contains raw
   big-endian 32-bit words; a string property contains NUL-terminated bytes and
   therefore ends in a `\0` you can see with `hexdump` but not with `cat`.
   Reading them as "plain text" produces subtly wrong conclusions.
2. **The sysfs view is the tree the kernel consumed**, not necessarily the file
   you think you booted. If you edited a blob, recompiled, and booted the *old*
   one, sysfs will faithfully show you the old tree.

---

## 2. Boot with an explicit DTB and capture bound evidence

```bash
bash scripts/run_qemu_dtb_boot.sh fixtures/qemu-virt.dtb \
    /path/to/zImage /path/to/rootfs.cpio.gz \
    build/boot.log build/boot.argv
```

The script:

* builds the argv from the canonical contract
  (`virt,highmem=off,gic-version=2`, `cortex-a7`, `512M`, `-smp 1`, `-nographic`);
* records that argv, plus the SHA-256 of the DTB, kernel and initramfs, as
  provenance;
* boots with `-dtb <your blob>` and an injected temporary initramfs overlay
  (`rdinit=/dtprobe_init`) that executes a bounded, read-only probe (printing
  `model` and the property names of `/pl011@9000000`), emits `DT-PROBE-END`,
  and powers off;
* fails closed (exit code 1) if QEMU fails or the guest fails to reach `DT-PROBE-END`.

Then bind the capture to your artifact:

```bash
python3 scripts/verify_runtime_binding.py \
    fixtures/qemu-virt.dtb build/boot.argv build/boot.log
```

The binder refuses to accept the capture unless the provenance records the
canonical machine contract, the logged kernel command line matches the
provenance bootargs, the probe completed, the guest-reported `model` equals your
candidate's root `model`, the guest-reported property list of the probed node
equals your candidate node's property names, **and** the booted blob is your
candidate (byte-identical, or semantically identical modulo the randomised
`chosen` seeds).

That last condition is what makes a capture *evidence about your artifact*
rather than evidence about "some boot".

---

## 3. The correlation table you must fill in

| # | What | Where in the tree | Where at runtime | What it proves | What it does **not** prove |
|---|---|---|---|---|---|
| 1 | node path | `/pl011@9000000` | `/sys/firmware/devicetree/base/pl011@9000000` | the node survived into the runtime tree | that a driver bound to it |
| 2 | `compatible` | `"arm,pl011\0arm,primecell\0"` | file `compatible` in that directory | the *identification key* the kernel matched on | that a matching driver exists |
| 3 | `reg` | `<0x00 0x09000000 0x00 0x1000>` | file `reg`, 16 raw bytes | the resource the kernel was told about | that the driver's `ioremap` succeeded |
| 4 | availability | absent `status` (available) | presence/absence of a `status` file | described vs available | that the hardware is present |
| 5 | one cross-checkable resource | `reg` base `0x09000000` | boot log / `/proc/iomem` | the address the *kernel* used | that the address is the one QEMU modelled |

### Reading a binary property correctly

```sh
cat  /sys/firmware/devicetree/base/pl011@9000000/compatible | hexdump -C
# 00000000  61 72 6d 2c 70 6c 30 31  31 00 61 72 6d 2c 70 72  |arm,pl011.arm,pr|
# 00000010  69 6d 65 63 65 6c 6c 00                           |imecell.|

hexdump -C /sys/firmware/devicetree/base/pl011@9000000/reg
# 00000000  00 00 00 00 09 00 00 00  00 00 00 00 00 00 10 00  |................|
```

`reg` is **not** the text `"0x09000000 0x1000"`. It is four big-endian 32-bit
cells. `00 00 00 00 09 00 00 00` is `0x0000000009000000` split across the two
address cells — which is only interpretable because the parent declares
`#address-cells = <2>`.

### Predict before you look

Use the derivation tool to state your expectation first, then compare:

```bash
python3 scripts/derive_sysfs_tree.py fixtures/qemu-virt.dtb --path "/pl011@9000000"
```

> The derivation tool renders the *predicted* projection from the blob. It is
> not a runtime capture, and the tool says so in its own header. If your
> prediction and your capture disagree, one of them is wrong — that is the
> interesting moment.

---

## 4. Checkpoint

1. You captured a boot with an explicit `-dtb` and the binding check passed.
2. You filled in the correlation table with real observations, keeping
   Observation / Interpretation / Non-Proof separate.
3. You can explain why `cat reg` is misleading and what to use instead.
4. You can state why "the runtime tree matches the file I inspected" needs the
   binding step to be a claim rather than a hope.

**Non-proof.** A successful boot proves the kernel accepted the blob. It does
not prove the blob is correct: a wrong `reg` that lands in unmapped space may
still boot, and a wrong `interrupts` may leave a device that is never exercised
looking healthy. Correctness of the description is established by interpreting
it against the hardware model — which is exactly what the Module Gate asks you
to do.
