# F12 — Local Package Source Modified but a Stale Binary Is Packaged

**Family:** Buildroot build-stamp / incremental propagation ·
**Introduced:** P3-M06 · **Gate competency:** Phase 3 Final Gate Part D
(build-system reproducibility)

> Worked **tutorial** fault. Hypotheses are written out deliberately; scored
> material never pre-writes them.

---

## 1. Mechanism

Buildroot is a **package-level state machine driven by stamp files**, not a
fine-grained file-dependency build. The authoritative statement is in
`docs/manual/rebuilding-packages.adoc` (Buildroot 2026.05.2):

> once a package has been built, it is never rebuilt unless explicitly told to
> do so.

The stamps live next to the package's build directory:

```text
output/build/appliance-diag-1.0/.stamp_configured
output/build/appliance-diag-1.0/.stamp_built
output/build/appliance-diag-1.0/.stamp_target_installed
```

(`package/pkg-generic.mk` defines `.stamp_target_installed` and derives the
per-package targets from it.)

Once `.stamp_target_installed` exists, the package phase is considered complete.
Editing the package source does not remove the stamp, and a top-level `make`
does not re-enter the package's build commands.

---

## 2. Reproduce

```bash
# a healthy, self-consistent synthetic output tree
python3 scripts/make_sample_output_tree.py --out build/f12 --mode healthy

# the package build area, with its stamps
ls -l --full-time build/f12/build/appliance-diag-1.0/

# now change the package source
sed -i 's/APPLIANCE-DIAG-BEGIN/APPLIANCE-DIAG-BEGIN-V2/' \
    fixtures/br2-external/package/appliance-diag/src/appliance-diag.c
```

The stamp files are unchanged, so a plain `make` skips the package entirely.
`output/target/` keeps the old binary; the image keeps the old binary.

---

## 3. Diagnostic chain

### Symptom

```text
EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED
The package source on the host has been modified and a top-level `make` has run.
The appliance boots, and the diagnostic utility still reports the previous
build identity.
```

### Own description

A source-level change to a local package is not reflected in the deployed image,
even though the build reported success.

### 3–5 hypotheses

1. The source edit was not saved to disk.
2. The top-level `make` did not run the package's build step because the package
   is considered already built.
3. The package was rebuilt, but the target installation step did not run.
4. The image was not re-packaged from the (updated) staging tree.
5. QEMU booted an image from a previous build.

### Experiment

```bash
# 1. Is the source actually modified?
grep -n 'APPLIANCE-DIAG-BEGIN' fixtures/br2-external/package/appliance-diag/src/appliance-diag.c

# 2. What does the build state claim?
ls -l --full-time output/build/appliance-diag-1.0/.stamp_*
stat -c '%y %n' output/build/appliance-diag-1.0/appliance-diag.c

# 3. Does a plain make enter the package at all?
make -C "$BR_SRC" O="$OUTPUT_DIR" BR2_EXTERNAL="$BR2_EXTERNAL" 2>&1 | grep -i appliance-diag

# 4. Does the *targeted* rebuild target enter it?
make -C "$BR_SRC" O="$OUTPUT_DIR" BR2_EXTERNAL="$BR2_EXTERNAL" appliance-diag-rebuild all
```

### Evidence

* The source file's mtime is **newer** than `.stamp_target_installed`.
* The plain `make` output contains no `appliance-diag` build lines: the package
  is skipped, because its stamp exists.
* The targeted rebuild prints the package's configure/build/install steps and
  the stamp files are re-created.

### Narrow scope

* The source is saved and syntactically valid — hypothesis 1 is out.
* The toolchain works and other packages are unaffected.
* The image file was rewritten, but from an unchanged `output/target/` —
  hypotheses 3 and 4 are narrowed to "the package's install step never ran".
* Re-running with the targeted rebuild changes the outcome, so the mechanism is
  build state, not the source — hypotheses 2 and 3 survive, 5 is out.

### Root cause

Two distinct layers of Buildroot caching are at work:

1. **Stamp gating**: `output/build/appliance-diag-1.0/.stamp_target_installed` exists and was not
   invalidated by the external source edit. A plain `make` therefore never re-entered the package.
2. **Local source extraction**: `appliance-diag.mk` uses `APPLIANCE_DIAG_SITE_METHOD = local`.
   Buildroot copies the external source tree to `output/build/appliance-diag-1.0` *once* during
   the extract phase (`.stamp_extracted`).
   Crucially, running `make appliance-diag-rebuild` only removes `.stamp_built` and
   `.stamp_target_installed`; it does **not** re-extract the external source! Thus, `-rebuild`
   alone rebuilds the *stale copy* already inside `output/build/`, leaving external source edits
   unpropagated.

### Fix

For `SITE_METHOD = local`, the clean recovery that forces re-extraction is:

```bash
make -C "$BR_SRC" O="$OUTPUT_DIR" BR2_EXTERNAL="$BR2_EXTERNAL" \
     appliance-diag-dirclean all
```

`appliance-diag-dirclean` completely removes `output/build/appliance-diag-1.0`, forcing Buildroot
to re-extract the updated source from `APPLIANCE_DIAG_SITE`, rebuild it, and regenerate the rootfs
image.

#### The `OVERRIDE_SRCDIR` Alternative for Active Development

If you are actively developing and modifying package source repeatedly, Buildroot provides the
`OVERRIDE_SRCDIR` mechanism (`docs/manual/using-buildroot-development.adoc`). By adding to
`local.mk`:

```make
APPLIANCE_DIAG_OVERRIDE_SRCDIR = $(BR2_EXTERNAL_QEMU_VIRT_A7_PATH)/package/appliance-diag/src
```

Buildroot switches from one-shot extraction to `rsync` before every build. Under this model,
`make appliance-diag-rebuild all` *does* pick up external edits because Buildroot re-rsyncs the
source before running the build step.

### Observable Build Identity

The build ID is injected at compile time via `APPLIANCE_DIAG_BUILD_ID` in `appliance-diag.mk`.
Inspecting `BUILD-ID` in the diagnostic output verifies whether the binary running or packaged
is the updated revision (e.g. `1.1`) rather than the stale initial build (`1.0`).

### Regression

```bash
python3 scripts/audit_output_tree.py \
    --output "$OUTPUT_DIR" \
    --overlay fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay
```

plus, where the environment permits, a boot whose capture is bound to the new
image hash and shows the updated `BUILD-ID`.

---

## 4. Why the "obvious" answers are wrong

* **"Just `make clean` and rebuild."** It works, it is slow, and it teaches you
  nothing about *which* state was stale. Use it as a comparison control, not as
  a diagnosis.
* **"Buildroot is buggy."** It is documented behaviour, stated explicitly in the
  manual. The build system is honest about what it does not do.
* **"The image is stale, so delete the image."** Deleting the image changes
  nothing: the staging tree it is built from is unchanged.

---

## 5. The point people miss

> **`output/build/`, `output/target/` and `output/images/` do not all prove the
> same thing.**

`output/build/` shows what the build *did*. `output/target/` shows what it
*intends to package*. `output/images/` is what you *deploy*. A change can appear
in one and not the others, and only a comparison across all three — plus a
bound runtime capture — closes the question.
