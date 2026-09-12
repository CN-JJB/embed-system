# P3-M05 Source Ledger — Device Tree First Pass

> Checked: **2026-09-11** (authoring host, Windows / Git Bash, no ARM kernel build available).
>
> This ledger separates what was **actually executed** from what was **pinned but
> not run**. Statuses are exactly `VERIFIED` / `PARTIALLY VERIFIED` / `UNVERIFIED`.
> Nothing in this module upgrades evidence by inference.

---

## 1. Upstream & specification traceability

| ID | Source / artifact | Organization | Type | Exact path / section | Version · tag · peeled commit | Upstream origin | Checked | Teaching purpose | Risk / constraint |
|---|---|---|---|---|---|---|---|---|---|
| M05-S01 | Devicetree Specification | devicetree.org | Primary specification | Chapters 2 (Design), 5 (Binary format) | **v0.4** · tag `v0.4` · `112f53cc57e5931f1503dfcaa1644caf15362c30` | `https://github.com/devicetree-org/devicetree-specification.git` | 2026-09-11 | Node/property model, cell encodings, `reg`, `interrupts`, `status`, phandles, DTB layout | Normative authority; CC-BY-4.0 |
| M05-S02 | Device Tree Compiler | devicetree.org / kernel.org | Official upstream tool | `dtc.c`, `flattree.c`, `livetree.c`, `libfdt/` | **v1.7.0** · tag `v1.7.0` · `039a99414e778332d8f9c04cbd3072e1dcc62798` | `https://git.kernel.org/pub/scm/utils/dtc/dtc.git` | 2026-09-11 | `dtb → dts → dtb` workflow and its exact CLI | GPL-2.0-or-later / BSD-2-Clause |
| M05-S03 | Linux and the Devicetree | Linux kernel community | Official documentation | `Documentation/devicetree/usage-model.rst` (420 lines) | **Linux 6.18.50 LTS** · tag `v6.18.50` · `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7` | `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git` | 2026-09-11 | How DT reaches Linux and becomes the runtime tree | GPL-2.0-only |
| M05-S04 | PL011 UART binding | Linux kernel community | Official binding | `Documentation/devicetree/bindings/serial/pl011.yaml` (130 lines) | Linux 6.18.50 (same commit) | same | 2026-09-11 | Required `compatible` / `reg` / `interrupts`; `clock-names` order | Normative for the console node |
| M05-S05 | ARM DT machine selection | Linux kernel community | Official upstream source | `arch/arm/kernel/devtree.c` (`setup_machine_fdt()`), `arch/arm/kernel/setup.c` (`setup_arch()`), `arch/arm/include/asm/mach/arch.h` (`struct machine_desc`) | Linux 6.18.50 (same commit) | same | 2026-09-11 | Root `compatible` → `machine_desc` matching | Cited by name only; **not** read line-by-line on the authoring host |
| M05-S06 | QEMU `virt` machine | QEMU project | Official upstream source / docs | `docs/system/arm/virt.rst`, `hw/arm/virt.c` | **QEMU 11.1.1** · tag `v11.1.1` · `c3d48b7d1e89604920e5b81b91140c2ad39a1943` | `https://gitlab.com/qemu-project/qemu.git` | 2026-09-11 | Canonical machine contract; `dumpdtb` | GPL-2.0. Source **not** cloned on the authoring host; the runtime binary is an actual-host alternate (see §3) |
| M05-S07 | Phase 3 curriculum design | this repository | Canonical curriculum architecture | `research/phase-3/2026-09-08-embedded-linux-curriculum-design.md` §P3-M05 | commit `200c46f69c1664cd28784573148add0f637c4f9a` | `roadmap/phase-3-embedded-linux.md` | 2026-09-11 | Module budget, labs 5.1–5.4, faults F10/F11 | Repository canonical |
| M05-S08 | Phase 3 platform contract | this repository | Canonical implementation | `fundamentals/linux/08-qemu-bootargs-console-diagnostics/SOURCE_LEDGER.md` §2 | merge `091a911676f4008b88eb4198c41398468647a8ac` | — | 2026-09-11 | Reused launch contract, no second appliance stack | Repository canonical |
| M05-S09 | Linux kernel parameters | Linux kernel community | Official documentation | `Documentation/admin-guide/kernel-parameters.rst` | Linux 6.18.50 (same commit) | same | 2026-09-11 | `console=`, `earlycon=`, `rdinit=` used by the runtime probe | — |

### Pin verification actually performed

Every tag below was resolved against its **real upstream remote** with
`git ls-remote --tags` on 2026-09-11. The peeled commit is what the repository
pins; the tag object is listed for completeness.

| Project | Tag object | Peeled commit | Matches curriculum pin |
|---|---|---|---|
| Linux | `7995d95093f421fc173190b2f7551d8e8b0ff86f` | `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7` | YES |
| QEMU | `5e35f26695645b20931e10d8567c7e0169e62c07` | `c3d48b7d1e89604920e5b81b91140c2ad39a1943` | YES |
| dtc | `66dbfc5bbbbc2aade889881a2b4358eab6b4fac7` | `039a99414e778332d8f9c04cbd3072e1dcc62798` | YES |
| devicetree-specification | `3bd573063e4d8c8e20879f935674516b87364243` | `112f53cc57e5931f1503dfcaa1644caf15362c30` | YES |

Additional identity checks:

* Linux 6.18.50 release tarball `linux-6.18.50.tar.xz` downloaded from
  `cdn.kernel.org` — SHA-256 `d2fc041dab4e11d9645e3ba53be058faa52b8ce28a8a97c889bb2cacee170461`.
  Both cited documentation files were extracted from it and read.
* dtc v1.7.0 release tarball `dtc-1.7.0.tar.xz` downloaded from
  `mirrors.edge.kernel.org` and **built locally**; the resulting binary reports
  `Version: DTC 1.7.0`. A git clone of `v1.7.0` confirmed the peeled commit
  `039a99414e778332d8f9c04cbd3072e1dcc62798`.

---

## 2. Canonical platform contract (reused, not redefined)

```text
qemu-system-arm \
  -machine virt,highmem=off,gic-version=2 \
  -cpu cortex-a7 \
  -m 512M \
  -smp 1 \
  -nographic
```

DTB generation adds `dumpdtb=<file>` to the machine string; booting adds
`-dtb <file>`, `-kernel <zImage>`, `-initrd <rootfs.cpio.gz>` and
`-append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init"`.

---

## 3. What was actually executed on the authoring host

| # | Action | Exact command (abridged) | Result | Status |
|---|---|---|---|---|
| 1 | Real DTB generation | `qemu-system-arm -machine virt,dumpdtb=virt.dtb,highmem=off,gic-version=2 -cpu cortex-a7 -m 512M -smp 1` | 1048576-byte blob produced | **VERIFIED** |
| 2 | dtc build from pinned source | `win_bison`/`win_flex` + `gcc -O2 -I. -Ilibfdt -o dtc.exe …` over the dtc v1.7.0 tarball | `dtc.exe` reports `Version: DTC 1.7.0` | **VERIFIED** |
| 3 | Decompile | `dtc -I dtb -O dts virt.dtb -o virt.dts` | 398-line DTS, 57 nodes | **VERIFIED** |
| 4 | Recompile + semantic equality | `dtc -I dts -O dtb virt.dts -o rebuilt.dtb` then `dt_roundtrip_check.py` | semantically identical | **VERIFIED** |
| 5 | DTB normalisation cross-check | `fdtlib_min.py --serialise` then `dtc -I dtb -O dts` on the result | dtc accepts it; same tree as the raw dump | **VERIFIED** |
| 6 | Semantic contract on the real tree | `validate_dt_semantics.py fixtures/qemu-virt.dtb` | PASS, 84 invariants | **VERIFIED** |
| 7 | Structural check on the real tree | `dt_structural_check.py fixtures/qemu-virt.dtb` | PASS, 11 invariants | **VERIFIED** |
| 8 | Fault construction (F10/F11 variants) | `fdt_patch.py` on the real fixture | seeds reproduce the intended REJECT | **VERIFIED** (static) |
| 9 | Non-determinism characterisation | two `dumpdtb` runs, semantic diff | differ only in `chosen/rng-seed` + `chosen/kaslr-seed` | **VERIFIED** |
| 10 | Kernel boot with `-dtb` | `run_qemu_dtb_boot.sh` | runner path fail-closed + deterministic composite initrd verified; boot not attempted on host (no ARM kernel built) | **UNVERIFIED** |
| 11 | `/sys/firmware/devicetree/base` correlation | `verify_runtime_binding.py` | composite initrd hash binding verified; live guest log not captured on host | **UNVERIFIED** |
| 12 | Live GDB / register observation | — | not applicable to this module | **UNVERIFIED** |
| 13 | Physical waveform / measurement | — | out of scope (QEMU-first curriculum) | **UNVERIFIED** |

### Actual-host vs canonical runtimes

| Dimension | Canonical | Actually used | Status |
|---|---|---|---|
| QEMU | 11.1.1 (`v11.1.1`, `c3d48b7d…`) | **11.1.0** (`v11.1.0-12130-ge470268ff4`) | **actual-host alternate** |
| dtc | v1.7.0 | **v1.7.0** (built from the pinned tarball) | canonical |
| Cross-toolchain | Arm GNU 13.3.rel1 (`arm-none-linux-gnueabihf-`) | none available | not used |
| Linux kernel | 6.18.50 LTS | source read only; **not built** | pin verified, build UNVERIFIED |

The QEMU build used is the Windows x86_64 w64 build published by the QEMU
project's Windows packager, SHA-512
`5bcf9eed634e8575a37b74f445af41a2fe4106da512d0c30c368301d4c105037fdfab40a5287367a28a957624cddebbc8c07e16c88ab6634f554cdf3d16bf543`,
which matched the publisher's own checksum file. It is **not** the canonical
11.1.1 runtime, and the module's documentation says so explicitly.

---

## 4. Committed artifacts and their provenance

| Artifact | Origin | Identity | Status |
|---|---|---|---|
| `fixtures/qemu-virt.dtb` | real QEMU dump, normalised to canonical FDT layout | sha256 `c91583017e34ac214562ebc80be7c229c53784ebd69575d92a7e304ec11327b1` | **VERIFIED** |
| `fixtures/qemu-virt.dts` | real `dtc -I dtb -O dts` of the raw dump | 398 lines, 57 nodes | **VERIFIED** |
| `fixtures/qemu-virt.provenance.json` | recorded by `scripts/dump_virt_dtb.sh` | raw dump sha256 `0442216cc4646fe7f59ff8ed759129d01b16f0df5786db58ae9a140427a18ad9` | **VERIFIED** |
| `fixtures/profiles/qemu-virt-a7-canonical.json` | values read out of the real DTB | 84 invariants pass | **VERIFIED** |
| `challenge/fixtures/starter_virt.dtb` | canonical fixture + reviewer seed | — | **VERIFIED** (deterministically generated) |
| `gate/fixtures/starter_virt.dtb` | canonical fixture + reviewer seed | — | **VERIFIED** (deterministically generated) |

No generated upstream source tree, no kernel build tree and no QEMU source tree
is committed.

---

## 5. Licensing / source-origin constraints

* Devicetree Specification v0.4 — CC-BY-4.0. Cited and paraphrased; no
  specification text is reproduced verbatim beyond short technical property
  names and normative definitions.
* dtc v1.7.0 — GPL-2.0-or-later / BSD-2-Clause. Used as a tool; not vendored.
* Linux 6.18.50 — GPL-2.0-only. Documentation quoted in short excerpts with the
  exact file and version identified; no kernel source is vendored.
* QEMU 11.1.1 — GPL-2.0. Used as a tool; not vendored.
* All module text, scripts, fixtures and validators are original work authored
  for this repository.

---

## 6. Evidence summary

| Dimension | Status |
|---|---|
| Linux source/version identity | **VERIFIED** (`git ls-remote` + tarball SHA-256 + extracted files read) |
| QEMU source/version identity | **VERIFIED** (pin resolved upstream); **actual-host runtime differs** |
| DTC source/version identity | **VERIFIED** (pin resolved; tool built from the pinned source and executed) |
| Devicetree specification identity | **VERIFIED** (`git ls-remote`) |
| Host/static validators | **VERIFIED** (executed) |
| DTB generation | **VERIFIED** (real QEMU execution) |
| DTB decompile/recompile | **VERIFIED** (real dtc execution + semantic equality) |
| DT artifact semantics | **VERIFIED** (84 semantic invariants on the real tree) |
| Actual-host QEMU runtime with DTB | **UNVERIFIED** (no kernel to boot) |
| Canonical QEMU 11.1.1 runtime | **UNVERIFIED** (not available on the authoring host) |
| Fault runtime reproduction | **UNVERIFIED** (static construction and semantic rejection verified) |
| Live GDB / registers | **UNVERIFIED** (not applicable) |
| Physical board | **UNVERIFIED** (out of scope) |
