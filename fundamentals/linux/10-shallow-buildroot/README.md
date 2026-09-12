# P3-M06 — Shallow Buildroot: Automated Pipeline, Rootfs Overlay & Provenance Auditing

**Time budget:** 3.5 h MUST (+ ≤ 1.0 h SHOULD)
**Prerequisites:** P3-M01 (toolchain), P3-M03 (manual rootfs / BusyBox / PID 1),
P3-M05 (device tree inspection)
**Platform:** ARMv7-A / Cortex-A7 on the canonical QEMU `virt` machine

---

## 1. Mission

You have built this appliance by hand. Now you reproduce it through automation —
and, more importantly, you learn to tell the difference between *the automation
ran* and *the appliance is correct*.

```text
Buildroot config
  → toolchain / packages / kernel / rootfs pipeline
  → output/build + output/target
  → output/images
  → QEMU boot artifacts
  → provenance / configuration / rebuild state
```

Every layer is compared against the manual P3-M03 workflow, so the automation
never becomes a black box.

---

## 2. What you will be able to do

* Explain what Buildroot automates and what it deliberately does not.
* Configure a generic ARM Cortex-A7 target with the correct hard-float ABI, and
  **verify every symbol against the pinned source tree** rather than from memory.
* Explain the roles of `output/build/`, `output/target/` and `output/images/`,
  and why `output/target/` is not the deliverable.
* Add a root filesystem overlay (`BR2_ROOTFS_OVERLAY`) and prove it reached both
  the staging tree **and** the packaged image.
* Boot the generated appliance under the canonical QEMU hardware contract and
  bind the runtime capture to the image hash.
* Diagnose a build-stamp propagation fault (F12) from real Buildroot state, and
  explain which changes propagate on a plain `make` and which do not.

**Explicitly out of scope:** Yocto/OpenEmbedded, deep package-maintainer
workflows, large custom external trees, systemd, production release
engineering, bootloader porting, Linux driver implementation.

---

## 3. Canonical platform contract (do not silently change)

| Component | Canonical | Identity |
|---|---|---|
| Buildroot | **2026.05.2** | tag `2026.05.2`, peeled commit `72d9d4fa636a371ef9eb99c92a735ce9f6d829d5` |
| Linux | **6.18.50 LTS** | tag `v6.18.50`, peeled commit `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7` |
| QEMU | **11.1.1** | tag `v11.1.1`, peeled commit `c3d48b7d1e89604920e5b81b91140c2ad39a1943` |
| Machine | `virt,highmem=off,gic-version=2` | `cortex-a7`, `-m 512M`, `-smp 1`, `-nographic` |
| ABI | hard-float | `BR2_ARM_EABIHF=y`, loader `/lib/ld-linux-armhf.so.3` |

Do not move to a different Buildroot release. Do not alter the kernel profile to
make the Buildroot exercise easier.

---

## 4. Layout

```text
10-shallow-buildroot/
  README.md                    this file
  SOURCE_LEDGER.md             exact pins, what was executed, evidence status
  Makefile                     learner-safe entry points
  labs/01-configure-cortex-a7/           Lab 6.1  (~40 min)
  labs/02-rootfs-overlay/                Lab 6.2  (~35 min)
  labs/03-kernel-rootfs-image-integration/ Lab 6.3  (~50 min)
  labs/04-output-tree-provenance-audit/  Lab 6.4  (~40 min)
  labs/05-incremental-rebuild-drift/     Lab 6.5  (~45 min)
  faults/F12-buildroot-stamp-fault/      worked tutorial fault
  challenge/                   AI-Free Challenge (practised family)
  gate/                        AI-Free Module Gate (unfamiliar variant)
  fixtures/                    verified symbol table, external tree, overlay,
                               synthetic output-tree sample
  scripts/                     learner-facing tooling
  reviewer (directory)         reviewer-only oracle, seeds and mutation suites
```

---

## 5. The mental model in one page

### 5.1 What Buildroot is

A set of Makefiles and Kconfig fragments that automates: fetching and building a
cross-toolchain, building packages, building the kernel, assembling a target
root filesystem, and packing filesystem images. It is **transparent** — you can
read every step — and it is **stateful** — it tracks progress per package with
stamp files.

### 5.2 Three directories, three questions

| Path | Question it answers |
|---|---|
| `output/build/<pkg>-<ver>/` | what the build *did* (with `.stamp_*` state) |
| `output/target/` | what the build *intends to package* (staging view) |
| `output/images/` | what you will *deploy* |

They can disagree. When they do, the one that matters is `output/images/`.

### 5.3 Overlay vs skeleton

`BR2_ROOTFS_OVERLAY` is a tree of files copied directly over the target
filesystem after the build. It is the supported, non-intrusive way to add your
own content, and — per the manual — an overlay change needs only a plain `make`,
while a **skeleton** change forces a full rebuild.

### 5.4 Stamps, not timestamps

Buildroot does not detect configuration changes and never rebuilds a package
unless told to. Overlay / post-build / post-image changes propagate on a plain
`make`; package source changes do not. The fix is the package's own rebuild
target (`make <pkg>-rebuild all`, or `-reconfigure` when configuration must be
regenerated) — not a full tree wipe.

### 5.5 Verified symbols, not remembered ones

Kconfig symbol names change between releases. Every symbol this module uses is
recorded in `fixtures/buildroot-symbols.json` with the **file and line** where it
is declared in the real 2026.05.2 tree, and the validator enforces that table.

---

## 6. Labs

| Lab | Title | Time | Deliverable |
|---|---|---:|---|
| 6.1 | Configure Buildroot for the canonical ARM target | 40 min | verified defconfig + symbol provenance |
| 6.2 | Root filesystem overlay | 35 min | overlay proven in `target/` and the image |
| 6.3 | Kernel / rootfs / image integration and boot | 50 min | bound runtime capture |
| 6.4 | Output-tree provenance audit | 40 min | per-artifact provenance table |
| 6.5 | Incremental rebuild and drift diagnosis | 45 min | stamp-based diagnosis + targeted fix |

---

## 7. Controlled fault

| ID | Fault | Family | Detection |
|---|---|---|---|
| **F12** | local package source modified, stale binary packaged | build-stamp / propagation | stamp inspection + targeted rebuild + image audit |

Worked tutorial. The scored Challenge and Module Gate use configuration-level
variants.

---

## 8. Assessment

Both the Challenge and the Module Gate are **AI-Free** on the first attempt.

* `challenge/README.md` — an opaque, well-formed but non-canonical configuration
  fragment; repair it and write the diagnostic chain.
* `gate/README.md` — an unfamiliar combined variant with extra required
  reasoning (artifact class per defect, provenance of the correct value, build
  success vs deployable success, non-proof).

Candidates are **data-only configuration fragments**, graded semantically by a
reviewer-only oracle that evaluates Kconfig relationships against the verified
symbol table. Learner-facing checks cover format and internal consistency only.

---

## 9. Verification

```bash
make check                       # learner-safe: docs, fixtures, contract, audit, staleness
make config-check                # canonical defconfig vs the taught contract
make symbols                     # every declared symbol vs the recorded 2026.05.2 table
make audit-sample                # audit the synthetic output-tree sample
make stale-sample                # demonstrate the stale-image detection
make gate-provision              # stage the Gate's opaque starter fragment
make challenge-provision         # stage the Challenge's opaque starter fragment
```

Building and booting (heavy, opt-in, needs a real Buildroot tree):

```bash
make build  BUILDROOT_SRC=/path/to/buildroot-2026.05.2
make boot   OUTPUT=build/br-output
```

Reviewer-only authoring regression (`make reviewer-check`) is never part of a
learner workflow.

---

## 10. Evidence boundary

* A valid configuration is not a valid build.
* A successful build is not a boot.
* A boot is not a verified appliance: the capture must be bound to the image
  hash, and the overlay must be proved present **and** executed.
* `output/target/` is a staging view; it never proves the image content.
* Buildroot source identity, the symbol table, the configuration contract, the
  external tree and the overlay propagation audit are VERIFIED on the authoring
  host. The Buildroot build and the appliance boot are **UNVERIFIED** there.
  See `SOURCE_LEDGER.md` for the exact split.
