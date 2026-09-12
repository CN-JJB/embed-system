# Lab 6.4 — Output-Tree Provenance Audit

**Time:** ~40 min. **Prerequisite:** Labs 6.1–6.3.

---

## 1. Three directories, three different meanings

The most common Buildroot mistake is treating `output/` as one thing. It is
three things, and they answer different questions:

| Path | What it is | What it proves |
|---|---|---|
| `output/build/<pkg>-<ver>/` | the extracted/compiled **package work area**, carrying `.stamp_*` state files | what the build *did* |
| `output/target/` | a **staging view** of the target filesystem, assembled by installing packages and applying the overlay | what the build *intends* to package |
| `output/images/` | the **final deployable artifacts** (`zImage`, `rootfs.cpio.gz`, `rootfs.ext4`) | what you are actually going to boot |

`output/target/` is **not** the filesystem image. It is the directory that the
image is built *from*. A build can update `target/` and fail to re-package the
image; the staging tree will then show a change that the image does not contain.
That is the single most expensive mistake this lab exists to prevent.

---

## 2. Run the audit

```bash
python3 scripts/audit_output_tree.py \
    --output fixtures/output-tree-sample \
    --overlay fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay
```

The sample is **synthetic** — a shape fixture, not a Buildroot build. It carries
a `SYNTHETIC` sentinel file and its own README says so. It exists so that the
audit tooling can be exercised, and deliberately broken, on any host.

---

## 3. The stale case

```bash
python3 scripts/make_sample_output_tree.py --out build/stale-sample --mode stale
python3 scripts/audit_output_tree.py \
    --output build/stale-sample \
    --overlay fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay
```

```text
[PASS] overlay.in-target  -- all 2 overlay file(s) present and identical in output/target
[FAIL] overlay.in-image   -- absent from the final image: ['etc/init.d/S99appliance-diag']
[FAIL] overlay.not-stale  -- STALE IMAGE: … exist in output/target but not in rootfs.cpio.gz
```

Both directories look plausible. Only the comparison tells them apart. Note that
`overlay.in-target` **passes** in the stale case — a validator that stopped there
would report success for an image that does not contain the customization.

---

## 4. Answer these for each artifact

For `output/images/rootfs.cpio.gz`, `output/images/zImage` and
`output/images/rootfs.ext4`:

1. **What produced it?** Which configuration symbol and which build stage.
2. **Intermediate or final?** Is it an input to another step, or the thing you
   deploy?
3. **How is its provenance identified?** The `.config` hash, the image hash, the
   `BUILD_PROVENANCE.txt` record, the package version, the `.stamp_*` files.
4. **What was the manual P3-M03 equivalent?** Which commands you ran by hand.
5. **What did Buildroot automate, and what is still yours?** Buildroot automates
   fetch/extract/patch/configure/build/install and image packing. It does *not*
   decide your overlay content, your kernel command line, your launch
   parameters, or whether the result is correct.

---

## 5. Checkpoint

1. You can state, in one sentence each, what `build/`, `target/` and `images/`
   are for.
2. You can explain why `overlay.in-target` passing does not imply
   `overlay.in-image` passing.
3. You can name the artifact in `output/images/` that you would hand to QEMU, and
   the flags you would pass with it.

**Non-proof.** A clean audit of `output/target/` and `output/images/` proves the
*packaging* is consistent. It does not prove the image boots, that the overlay
content executes, or that the kernel is the one you think it is. Those need
runtime evidence bound to the image hash.
