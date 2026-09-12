# Phase 5 — BSP, Bootloader, Build Systems and Board Integration

> **Authoring model:** resource-first. The objective is to learn how a production embedded Linux image is assembled and maintained, not to create a giant AI-authored BSP tutorial.

## Exit capability

By the end of Phase 5, the learner should be able to:

- explain what a BSP actually contains and what it does not;
- trace boot from ROM/firmware into U-Boot and Linux at the level needed for board integration;
- manage kernel config, patches and Device Tree as source-controlled BSP inputs;
- use Buildroot confidently for a small embedded product;
- understand the Yocto/OpenEmbedded layer/recipe/task/signature model well enough to work in a production BSP;
- distinguish board support, machine metadata, packages, images and application layers;
- debug “works in source tree but not in final image” propagation problems;
- reason about reproducibility, licenses, CVEs and update strategy;
- make a bounded change crossing bootloader/DT/kernel/rootfs/build-system layers.

---

# P5-1 — BSP mental model

## Learn

A BSP is an integration boundary, not merely a kernel tree.

Typical inputs:

```text
boot firmware / ROM assumptions
→ bootloader
→ Device Tree / firmware description
→ Linux kernel config + patches
→ drivers
→ root filesystem packages/config
→ build-system metadata
→ image layout / update artifacts
```

For a vendor product, the BSP may also include firmware blobs, trusted firmware, security configuration, manufacturing scripts and board-specific tooling.

## Suggested exercise

Take one real board's vendor BSP and classify every major repository/component by layer. Do not start modifying it yet.

---

# P5-2 — U-Boot fundamentals

## Learn

- U-Boot build/config orientation;
- environment and boot scripts;
- loading kernel/DT/initramfs;
- `booti`/`bootz`/FIT orientation as appropriate to target;
- working FDT vs U-Boot control FDT concept;
- driver model orientation;
- board configuration and defconfig;
- boot media and image placement;
- debugging commands.

## Primary resources

U-Boot documentation:
https://docs.u-boot.org/en/latest/

Useful sections include driver model, command reference, Device Tree handling, debugging/testing and image/boot documentation.

## Suggested experiment

On a supported board or QEMU platform:

1. interrupt autoboot;
2. inspect environment;
3. manually load kernel + DT + rootfs;
4. modify one boot argument;
5. inspect/modify the working FDT in memory;
6. boot;
7. explain exactly which artifacts U-Boot passed to Linux.

## Defer

- DDR training code;
- SPL/TPL deep porting;
- secure monitor/TEE integration;
- board bring-up from completely unsupported silicon.

Those become necessary only for deeper platform roles.

---

# P5-3 — Buildroot as transparent BSP/build-system practice

## Learn

- defconfig and Kconfig;
- toolchain choices;
- packages;
- rootfs overlays;
- post-build/post-image hooks;
- filesystem/image generation;
- `BR2_EXTERNAL`;
- package rebuild/stamp semantics;
- output/build vs output/target vs output/images;
- reproducibility/licensing/CVE tooling orientation.

## Primary resources

Buildroot manual:
https://buildroot.org/downloads/manual/manual.html

Bootlin Buildroot training:
https://bootlin.com/training/buildroot/

## Suggested project

Create a small board configuration that:

- builds kernel + DT + rootfs;
- adds one original application/package;
- creates one rootfs customization;
- generates a reproducible image;
- records exact external source revisions;
- survives a clean rebuild.

Then intentionally create a stale package/image condition and diagnose it.

---

# P5-4 — Yocto/OpenEmbedded concepts

Do not begin Yocto until Buildroot has made the build-pipeline problem concrete.

## Learn

- Poky/reference distribution concept;
- OpenEmbedded metadata;
- layers;
- recipes and `.bbappend`;
- machine/distro/image configuration;
- tasks and dependency graph;
- task signatures;
- shared state (`sstate`);
- `WORKDIR`, sysroots, deploy artifacts;
- package/image relationship;
- kernel recipes/config fragments/patches;
- devtool orientation;
- SDK/eSDK orientation.

## Primary resources

Yocto documentation:
https://docs.yoctoproject.org/

Start with Overview and Concepts:
https://docs.yoctoproject.org/dev/overview-manual/index.html

Then consult, as needed:

- BSP Developer's Guide;
- Development Tasks Manual;
- Linux Kernel Development Manual;
- Reference Manual.

BitBake manual:
https://docs.yoctoproject.org/bitbake/dev/singleindex.html

Bootlin Yocto/OpenEmbedded training:
https://bootlin.com/training/yocto/

## Suggested experiment

Build a reference image, then make **one** controlled customization each at different layers:

- add a package;
- modify a recipe with `.bbappend`;
- apply a kernel config fragment or patch;
- change machine-specific DT;
- inspect which tasks rerun and why.

The key question is not “what command builds it?” but “which metadata caused which task/artifact to change?”

---

# P5-5 — Kernel/DT patch management inside a BSP

## Learn

- why vendor kernel branches exist;
- upstream vs LTS vs vendor tree;
- config fragments;
- patch series;
- DT source organization;
- backports;
- out-of-tree vs upstream driver cost;
- rebasing/upgrading BSPs.

## Suggested source-reading exercise

Pick one vendor BSP patch and determine:

- what upstream subsystem it touches;
- whether equivalent support exists upstream;
- whether the patch is hardware-specific, bug fix, or product policy;
- what breaks if it is dropped during an upgrade.

---

# P5-6 — Image layout and update orientation

## Learn

At practical architecture depth:

- boot partitions;
- rootfs formats;
- read-only vs writable areas;
- A/B update concept;
- recovery image;
- artifact versioning;
- signed images/verified boot orientation;
- rollback and power-loss considerations.

Do not choose an OTA framework before the product's failure/recovery model is understood.

## Suggested design exercise

Draw two image/update architectures:

1. simple development image;
2. production A/B update image.

For each, explain what happens on power loss during update and how rollback is decided.

---

# P5-7 — Licensing, CVEs, SBOM and reproducibility orientation

## Learn

- open-source license obligations at practical depth;
- source offer / notices where applicable;
- package license metadata;
- CVE feeds/scanning limitations;
- SBOM concept;
- deterministic/reproducible build goals;
- why exact source revisions and artifact provenance matter.

Use Buildroot/Yocto's native tooling before inventing a separate system.

---

# Capstone direction

Take one board or emulator target and maintain a small BSP-like integration repository containing only source-controlled inputs:

```text
README / manifest
bootloader config or environment
kernel config fragments / patches
DT changes
Buildroot or Yocto metadata
one application/package
image instructions
bring-up/debug notes
```

Acceptance should be practical:

- clean clone can reproduce a bootable image;
- one board-specific change is understood across layers;
- artifacts can be traced to source/config inputs;
- a stale-build/config fault can be diagnosed;
- no unexplained manual step is required.

---

# Common traps

- calling a vendor SDK “the BSP” without understanding its layers;
- learning Yocto syntax before understanding the build pipeline;
- editing generated files under build output instead of source metadata;
- carrying patches without knowing whether upstream already solved the problem;
- putting board-specific policy into generic drivers;
- treating DT as a configuration dumping ground;
- relying on undocumented U-Boot environment state;
- mixing development convenience and production update architecture;
- assuming a successful incremental build proves reproducibility.

---

# What to defer

Until the role/project needs it:

- secure boot implementation details;
- TF-A/OP-TEE deep integration;
- advanced UEFI;
- complex OTA frameworks;
- factory provisioning infrastructure;
- multi-product Yocto distribution architecture;
- custom boot ROM / DDR PHY bring-up.
