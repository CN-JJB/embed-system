# Lab 5.1 — Dump the QEMU `virt` Device Tree

**Time:** ~30 min. **Prerequisite:** P3-M04 (QEMU bring-up and bootargs).

---

## 1. Why

On the canonical platform the kernel is generic. It does not know that a PL011
UART lives at `0x09000000`; QEMU *tells* it, by building a device tree at
machine-construction time and handing the blob to the kernel at boot. Before
you can reason about a device tree you need the real one, produced by the real
machine — not a toy tree, and not a diagram.

QEMU can emit exactly the blob it would have booted with, without booting
anything, through the `dumpdtb` machine property.

---

## 2. Do it

The canonical Phase 3 hardware model must be preserved exactly. `dumpdtb` is
added to the same `-machine` string:

```bash
mkdir -p build
qemu-system-arm \
    -machine virt,dumpdtb=build/virt.raw.dtb,highmem=off,gic-version=2 \
    -cpu cortex-a7 \
    -m 512M \
    -smp 1
```

QEMU writes the blob and exits — no kernel, no initramfs, no console.

The module wraps this and records provenance:

```bash
bash scripts/dump_virt_dtb.sh build/virt.dtb build/virt.provenance.json
```

---

## 3. Understand what you got

### 3.1 The blob is padded

```bash
ls -l build/virt.raw.dtb          # ~1048576 bytes
```

That is **not** the size of the tree. It is the size of the DTB reserve QEMU
allocates for the machine. The header's `totalsize` field describes the reserve,
so "the file is 1 MiB" tells you nothing about the tree.

The wrapper re-serialises the same tree in canonical layout and *verifies* that
the tree is unchanged before accepting the result:

```bash
python3 scripts/fdtlib_min.py build/virt.dtb
# FDT version=17 totalsize=7696 reservations=0 nodes=57
```

### 3.2 It is not byte-reproducible

Dump it twice and compare:

```bash
qemu-system-arm -machine virt,dumpdtb=build/a.dtb,highmem=off,gic-version=2 \
    -cpu cortex-a7 -m 512M -smp 1
qemu-system-arm -machine virt,dumpdtb=build/b.dtb,highmem=off,gic-version=2 \
    -cpu cortex-a7 -m 512M -smp 1
sha256sum build/a.dtb build/b.dtb        # different!
python3 scripts/fdtlib_min.py build/a.dtb --dump --skip-props "" > build/a.dump
python3 scripts/fdtlib_min.py build/b.dtb --dump --skip-props "" > build/b.dump
diff build/a.dump build/b.dump
```

The only differences are `/chosen/rng-seed` and `/chosen/kaslr-seed`: QEMU
randomises them per run.

> **Lesson.** A device tree blob's *hash* is not a stable identity. Two blobs
> that describe exactly the same hardware have different hashes. When you need
> to prove "the tree I inspected is the tree that booted", you must compare
> *trees*, and you must record which properties you excluded and why.

---

## 4. Record provenance

Every later claim in this module depends on knowing which QEMU produced the
artifact. `build/virt.provenance.json` records:

| Field | Meaning |
|---|---|
| `qemu_version_string` | the runtime **actually used** on your host |
| `machine`, `cpu`, `memory`, `smp` | the exact hardware model |
| `raw_dump_sha256` | identity of the unmodified dump |
| `normalised_sha256` | identity of the artifact you will reason about |
| `nondeterministic_properties` | properties that legitimately vary |

**Canonical vs actual host.** The curriculum baseline is QEMU **11.1.1**
(tag `v11.1.1`, peeled commit `c3d48b7d1e89604920e5b81b91140c2ad39a1943`).
Whatever version your host provides is an *actual-host alternate*. They are
separate evidence dimensions: do not silently substitute one for the other, and
say which one you used in every write-up.

---

## 5. Checkpoint

1. `build/virt.dtb` exists and parses (`scripts/fdtlib_min.py`).
2. `build/virt.provenance.json` records the QEMU version you actually ran.
3. You can explain, in one sentence each:
   * why the raw dump is much larger than the tree;
   * why two dumps of the same machine have different hashes;
   * which two properties cause that, and what they are for.

**Non-proof.** Producing this blob proves that QEMU can generate a device tree
for this machine. It does **not** prove that any kernel consumed it, that any
driver probed, or that the tree is correct for anything other than the exact
`-machine`/`-cpu`/`-m`/`-smp` combination you passed.
