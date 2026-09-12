# P3-M06 Source Ledger — Shallow Buildroot

> Checked: **2026-09-11** (authoring host, Windows / Git Bash, no POSIX Buildroot build available).
>
> This ledger separates what was **actually executed** from what was **pinned but
> not run**. Statuses are exactly `VERIFIED` / `PARTIALLY VERIFIED` / `UNVERIFIED`.
> Nothing in this module upgrades evidence by inference.

---

## 1. Upstream traceability

| ID | Source / artifact | Organization | Type | Exact path / section | Version · tag · peeled commit | Upstream origin | Checked | Teaching purpose | Risk / constraint |
|---|---|---|---|---|---|---|---|---|---|
| M06-S01 | Buildroot automated build system | Buildroot project | Official upstream source | `Makefile`, `arch/Config.in`, `arch/Config.in.arm`, `system/Config.in`, `fs/*/Config.in`, `linux/Config.in`, `package/pkg-generic.mk` | **2026.05.2** · tag `2026.05.2` · `72d9d4fa636a371ef9eb99c92a735ce9f6d829d5` | `https://gitlab.com/buildroot.org/buildroot.git` | 2026-09-11 | Every configuration symbol used by the module, with file/line provenance | GPL-2.0-or-later. **Not** built on the authoring host |
| M06-S02 | Buildroot manual — customizing the target filesystem | Buildroot project | Official documentation | `docs/manual/customize-rootfs.adoc` (anchor `rootfs-custom`) | 2026.05.2 (same commit) | same | 2026-09-11 | `BR2_ROOTFS_OVERLAY` semantics, exclusion rules, recommended overlay path | **Path correction:** the design document cites `docs/manual/customize-rootfs.txt`; in 2026.05.2 the manual is AsciiDoc and that file does **not** exist |
| M06-S03 | Buildroot manual — rebuilding packages | Buildroot project | Official documentation | `docs/manual/rebuilding-packages.adoc` (anchor `full-rebuild`) | 2026.05.2 (same commit) | same | 2026-09-11 | The authoritative statement of the F12 mechanism: Buildroot does not detect configuration changes, and never rebuilds a package unless told to | Normative for F12 |
| M06-S04 | Buildroot manual — package-specific make targets | Buildroot project | Official documentation | `docs/manual/package-make-target.adoc` (anchor `pkg-build-steps`) | 2026.05.2 (same commit) | same | 2026-09-11 | The per-package `<target>` make targets used by the F12 fix | Normative for F12 |
| M06-S05 | BusyBox package infrastructure | Buildroot project | Official upstream source | `package/busybox/busybox.mk`, `package/busybox/Config.in` | 2026.05.2 (same commit) | same | 2026-09-11 | How Buildroot builds the userspace baseline that P3-M03 assembled by hand | Reference only |
| M06-S06 | Buildroot target skeleton | Buildroot project | Official upstream source | `system/skeleton/` | 2026.05.2 (same commit) | same | 2026-09-11 | Why the overlay is preferred over editing the skeleton | Reference only |
| M06-S07 | Linux kernel source | Linux kernel community | Official upstream source | `Documentation/devicetree/usage-model.rst`, kernel Kconfig integration via `linux/Config.in` | **Linux 6.18.50 LTS** · tag `v6.18.50` · `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7` | `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git` | 2026-09-11 | The kernel release the appliance is pinned to | Pin verified upstream |
| M06-S08 | QEMU system emulator | QEMU project | Official upstream source | `docs/system/arm/virt.rst` | **QEMU 11.1.1** · tag `v11.1.1` · `c3d48b7d1e89604920e5b81b91140c2ad39a1943` | `https://gitlab.com/qemu-project/qemu.git` | 2026-09-11 | The canonical launch contract reused from P3-M04 | Actual-host runtime differs (see §3) |
| M06-S09 | Phase 3 curriculum design | this repository | Canonical curriculum architecture | `research/phase-3/2026-09-08-embedded-linux-curriculum-design.md` §P3-M06 | commit `200c46f69c1664cd28784573148add0f637c4f9a` | `roadmap/phase-3-embedded-linux.md` | 2026-09-11 | Module budget, labs 6.1–6.5, fault F12 | Repository canonical |
| M06-S10 | Phase 3 platform contract | this repository | Canonical implementation | `fundamentals/linux/08-qemu-bootargs-console-diagnostics/SOURCE_LEDGER.md` §2 | merge `091a911676f4008b88eb4198c41398468647a8ac` | — | 2026-09-11 | Reused launch contract, no second appliance stack | Repository canonical |

### Pin verification actually performed

Every tag below was resolved against its **real upstream remote** with
`git ls-remote --tags` on 2026-09-11, and the Buildroot release tarball was
downloaded and inspected.

| Project | Tag object | Peeled commit | Matches curriculum pin |
|---|---|---|---|
| Buildroot | `d5774f1666c406402abc46c94aa1517775dd61af` | `72d9d4fa636a371ef9eb99c92a735ce9f6d829d5` | YES |
| Linux | `7995d95093f421fc173190b2f7551d8e8b0ff86f` | `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7` | YES |
| QEMU | `5e35f26695645b20931e10d8567c7e0169e62c07` | `c3d48b7d1e89604920e5b81b91140c2ad39a1943` | YES |

Release artifact identity:

* `buildroot-2026.05.2.tar.xz` downloaded from `buildroot.org` (6 119 252 bytes).
  `Makefile:95` reads `export BR2_VERSION := 2026.05.2`, matching the pin.
* The extracted tree was used to verify every symbol in
  `fixtures/buildroot-symbols.json` (file + line).

---

## 2. Symbol verification (the module's central source claim)

`fixtures/buildroot-symbols.json` records 25 upstream symbols and 1 symbol
defined by this repository's external tree, each with the file and line where it
is declared. The verification command is mechanical and reproducible:

```bash
grep -rn '^config BR2_ROOTFS_OVERLAY$' system/Config.in     # 655
grep -rn '^config BR2_cortex_a7$'      arch/Config.in.arm   # 190
grep -rn '^config BR2_ARM_EABIHF$'     arch/Config.in.arm   # 617
grep -rn '^config BR2_arm$'            arch/Config.in       # 33
```

Two facts read directly out of the source, not recalled:

* `BR2_cortex_a7` (`arch/Config.in.arm:190`) **selects**
  `BR2_ARM_CPU_HAS_VFPV4`, `BR2_ARM_CPU_HAS_NEON`, `BR2_ARM_CPU_HAS_THUMB2` and
  `BR2_ARM_CPU_ARMV7A`.
* `BR2_ARM_EABIHF` (`arch/Config.in.arm:617`) **depends on**
  `BR2_ARM_CPU_HAS_FPU`, and sits in the same `choice` as `BR2_ARM_EABI`
  (`arch/Config.in.arm:593`).

### Documented path correction

The Phase 3 design document directs the reader to
`docs/manual/customize-rootfs.txt`. **That file does not exist in Buildroot
2026.05.2.** The manual in this release is AsciiDoc; the correct path is
`docs/manual/customize-rootfs.adoc` (anchor `rootfs-custom`). This module uses
the verified path and records the discrepancy here rather than silently
following the stale reference.

---

## 3. What was actually executed on the authoring host

| # | Action | Exact command (abridged) | Result | Status |
|---|---|---|---|---|
| 1 | Buildroot release identity | download tarball; `sed -n 's/^export BR2_VERSION := //p' Makefile` | `2026.05.2` | **VERIFIED** |
| 2 | Symbol existence + location | `grep -rn '^config BR2_<name>$' <file>` over the extracted tree | all 30 symbols located; file/line recorded | **VERIFIED** |
| 3 | Overlay semantics | read `docs/manual/customize-rootfs.adoc` | copy-over-target semantics, exclusion rules, recommended path | **VERIFIED** |
| 4 | Rebuild semantics | read `docs/manual/rebuilding-packages.adoc` | "never rebuilt unless explicitly told to do so"; overlay change needs only `make` | **VERIFIED** |
| 5 | Package make targets | read `docs/manual/package-make-target.adoc`; `grep .stamp_target_installed package/pkg-generic.mk` | stamp-based package phases confirmed | **VERIFIED** |
| 6 | Canonical defconfig vs taught contract | `verify_br_config.py <defconfig>` | PASS | **VERIFIED** |
| 7 | Canonical defconfig vs complete contract + symbol table | `verify_br_config.py <defconfig> --profile …complete.json --symbol-table …` | PASS | **VERIFIED** |
| 7b | Effective resolved `.config` validation | `verify_br_config.py <.config> --profile …complete.json --symbol-table … --effective` | PASS on healthy, REJECT on mutated | **VERIFIED** (tooling) |
| 8 | External-tree structure | `external.desc`, `external.mk`, `Config.in`, `configs/`, `package/`, `board/` | consistent with documented BR2_EXTERNAL layout | **VERIFIED** (structural) |
| 9 | Overlay propagation audit (synthetic sample) | `make_sample_output_tree.py` + `audit_output_tree.py` | healthy PASS; stale REJECT (`overlay.in-image`, `overlay.not-stale`) | **VERIFIED** (tooling) |
| 10 | Real Buildroot build / defconfig smoke | `make … qemu_virt_a7_defconfig` | fail-closed reviewer runner implemented; real build UNVERIFIED on host | **UNVERIFIED** |
| 11 | Real appliance QEMU boot | `run_buildroot_appliance.sh` | not attempted — no image exists on host | **UNVERIFIED** |
| 12 | Real overlay propagation into a real `rootfs.ext4` | `audit_output_tree.py` on a real build | not attempted on host | **UNVERIFIED** |
| 13 | F12 local-site rebuild fidelity | `test_f12_real_buildroot.sh` & synthetic unit suite (Tests 23–27) | unit suite PASS; real Buildroot execution gated on `BUILDROOT_SRC` | **PARTIALLY VERIFIED** (synthetic PASS, real path UNVERIFIED on host) |
| 14 | Live GDB / physical measurement | — | not applicable | **UNVERIFIED** |

### Actual-host vs canonical

| Dimension | Canonical | Actually used | Status |
|---|---|---|---|
| Buildroot | 2026.05.2 | **2026.05.2 source inspected only** | pin VERIFIED, build UNVERIFIED |
| QEMU | 11.1.1 (`v11.1.1`) | 11.1.0 (`v11.1.0-12130-ge470268ff4`) | **actual-host alternate** |
| Linux | 6.18.50 LTS | pin verified; **not built** | build UNVERIFIED |
| Host | POSIX (Linux) | Windows / Git Bash | **not the canonical build host** |

---

## 4. Committed artifacts and their provenance

| Artifact | Origin | Status |
|---|---|---|
| `fixtures/buildroot-symbols.json` | extracted from the real 2026.05.2 tree | **VERIFIED** |
| `fixtures/br2-external/configs/qemu_virt_a7_defconfig` | authored; every symbol verified against the real tree | **VERIFIED** |
| `fixtures/br2-external/**` | original work authored for this repository | **VERIFIED** (structure) |
| `fixtures/profiles/buildroot-2026.05.2-taught.json` | authored contract, values cross-checked against the defconfig | **VERIFIED** |
| `fixtures/output-tree-sample/**` | **SYNTHETIC** — generated by `scripts/make_sample_output_tree.py`; not a Buildroot build | **VERIFIED** (tooling fixture) |
| `challenge/fixtures/starter.conf`, `gate/fixtures/starter.conf` | canonical defconfig + reviewer seed | **VERIFIED** (deterministically generated) |

No Buildroot source tree, no `output/` tree from a real build, no toolchain and
no kernel build tree is committed.

---

## 5. Licensing / source-origin constraints

* Buildroot 2026.05.2 — GPL-2.0-or-later. Used as a source reference and a tool;
  not vendored. Manual text is quoted in short excerpts with the exact file
  identified.
* Linux 6.18.50 — GPL-2.0-only. Pin verified; no kernel source vendored.
* QEMU 11.1.1 — GPL-2.0. Used as a tool; not vendored.
* All module text, the external tree, the appliance diagnostic utility, the
  overlay content, the sample output tree, the scripts and the validators are
  original work authored for this repository. `appliance-diag` carries an
  explicit MIT license file in its source directory.

---

## 6. Evidence summary

| Dimension | Status |
|---|---|
| Buildroot source/version identity | **VERIFIED** (`git ls-remote` + tarball inspection + `BR2_VERSION`) |
| Exact 2026.05.2 configuration symbols | **VERIFIED** (25 upstream + 1 external, each with file/line) |
| Buildroot documentation paths | **VERIFIED**; one stale path in the design document corrected |
| Host/static validators | **VERIFIED** (executed) |
| Buildroot configuration provenance | **VERIFIED** (canonical defconfig passes both contracts) |
| Rootfs overlay configuration + propagation audit | **VERIFIED** on the synthetic sample; **UNVERIFIED** on a real build |
| Buildroot real build | **UNVERIFIED** (host is not a POSIX Buildroot host) |
| Final image artifact audit | **VERIFIED** (tooling, synthetic); **UNVERIFIED** (real `rootfs.ext4`) |
| Buildroot appliance QEMU boot/runtime | **UNVERIFIED** |
| Fault runtime reproduction (F12) | **UNVERIFIED** (mechanism verified from the manual; tooling demonstrated on the sample) |
| Live GDB / registers | **UNVERIFIED** (not applicable) |
| Physical board | **UNVERIFIED** (out of scope) |
