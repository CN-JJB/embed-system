# Lab 6.2 — Root Filesystem Overlay

**Time:** ~35 min. **Prerequisite:** Lab 6.1, P3-M03.

---

## 1. Why an overlay, and why not the skeleton

Buildroot offers two ways to put your own files into the target filesystem:

* modify `system/skeleton/`, the directory tree Buildroot itself uses as the
  starting point for the target rootfs; or
* point `BR2_ROOTFS_OVERLAY` at a directory of your own.

The manual is explicit about the mechanism and the recommended layout
(`docs/manual/customize-rootfs.adoc` in the 2026.05.2 tree — note that in this
release the manual is AsciiDoc, so `customize-rootfs.txt` does **not** exist):

> A filesystem overlay is a tree of files that is copied directly over the
> target filesystem after it has been built. [...] If you specify a relative
> path, it will be relative to the root of the Buildroot tree. [...] the
> recommended path for this overlay is `board/<company>/<boardname>/rootfs-overlay`.

The overlay is the right tool because it is *yours*: it is version-controlled in
your external tree, it survives a Buildroot upgrade, and it is trivially
auditable. Touching the skeleton makes your customization indistinguishable from
Buildroot's own content — and the manual warns that a skeleton change forces a
full rebuild, while an overlay change does not.

---

## 2. The overlay in this module

```text
fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay/
├── etc/
│   ├── appliance-release                 # identity marker
│   └── init.d/S99appliance-diag          # runs the diagnostic at boot
```

Both files are original, deterministic, and trivially distinguishable from
anything BusyBox or the base filesystem installs:

```bash
cat fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay/etc/appliance-release
# EMBED-SYSTEM P3-M06 appliance release 1.0
```

The init script prints `APPLIANCE-OVERLAY-BOOT-MARKER` and then runs
`/usr/bin/appliance-diag`, which is the local package from the external tree.

> **Do not use the overlay to hide answers.** The overlay exists so that a
> customization can be *traced* from source to staging tree to final image to
> runtime. It is not a place to park solutions to an assessment.

---

## 3. Watch it propagate

```bash
python3 scripts/audit_output_tree.py \
    --output fixtures/output-tree-sample \
    --overlay fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay
```

You should see the overlay reported as present and byte-identical in **both**
`output/target/` and the final image.

Now look at what the audit is actually comparing:

| Check | Question it answers |
|---|---|
| `overlay.source` | what is in the overlay |
| `overlay.in-target` | did it reach the staging tree |
| `overlay.in-image` | did it reach the **packaged image** |
| `overlay.not-stale` | is the image newer than the staging tree, or does the staging tree lie |
| `overlay.no-decoy` | is the marker merely a string somewhere, or the actual file |

The distinction between the middle three is the whole point of Lab 6.4.

---

## 4. Exclusion rules you should know

The manual lists what an overlay does *not* copy: version-control directories
(`.git`, `.svn`, `.hg`), files named `.empty`, and files ending in `~`. The
module's own audit tool implements the same rules, so a file you expect to be
copied but which is excluded by name will show up as "missing from the image"
rather than silently vanishing.

---

## 5. Checkpoint

1. You can state the difference between an overlay change and a skeleton change,
   and which one forces a full rebuild.
2. You can explain why the overlay is stored in the external tree rather than
   inside the Buildroot source tree.
3. The audit reports the overlay present in both `target/` and the image.

**Non-proof.** Seeing the file in `output/target/` does not prove it is in the
image you are about to boot, and seeing it in the image does not prove anything
executed it. Both claims need separate evidence.
