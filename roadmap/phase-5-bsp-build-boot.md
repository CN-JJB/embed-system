# Phase 5 — BSP, Bootloader, Build Systems and Board Integration

> **Authoring model:** resource-first. The objective is to understand how a production embedded-Linux image is assembled and maintained, not to create a giant AI-authored BSP tutorial.

## How to navigate this phase

Use the same unit IDs everywhere:

- [`../START_HERE.md`](../START_HERE.md) — order and next action;
- [`../resources/TOPIC_RESOURCE_INDEX.md`](../resources/TOPIC_RESOURCE_INDEX.md) — exact documents/headings/source targets/experiments;
- this file — phase scope and dependencies.

```text
P5.1 BSP layer mental model
→ P5.2 U-Boot standard boot / environment / FDT
→ P5.3 Buildroot project customization
→ P5.4 Yocto/OE metadata / tasks / signatures / sstate
→ P5.5 kernel + DT patch/config management
→ P5.6 image layout / recovery / update architecture
→ P5.7 licensing / CVE / SBOM / reproducibility
→ P5.8 board-integration capstone
```

## Exit capability

By the end of Phase 5, the learner should be able to:

- explain what a BSP contains and what it does not;
- trace boot from firmware/ROM assumptions through U-Boot to Linux;
- manage kernel config, patches and DT as source-controlled BSP inputs;
- use Buildroot confidently for a small embedded product;
- understand Yocto/OpenEmbedded layer/recipe/task/signature/sstate concepts well enough to work in a production BSP;
- distinguish board support, machine metadata, packages, images and application layers;
- debug “changed source but not final image” propagation failures;
- reason about image/update/recovery, licenses, CVEs, SBOM and reproducibility;
- make a bounded change crossing at least two BSP layers.

---

## P5.1 — BSP layer mental model

A BSP is an integration boundary, not merely a kernel tree.

Typical source-controlled inputs:

```text
firmware / ROM assumptions
→ bootloader configuration
→ DT / firmware description
→ Linux kernel config + patches
→ drivers
→ rootfs packages/config
→ build-system metadata
→ image/update layout
```

A product may also include firmware blobs, trusted firmware, security/manufacturing configuration and board tooling.

### Exact resource entry

Use **P5.1** in [`../resources/TOPIC_RESOURCE_INDEX.md`](../resources/TOPIC_RESOURCE_INDEX.md).

### Suggested exercise

Take one public board/vendor stack and classify every major repository/component by layer. Mark generated outputs separately from source-controlled inputs.

---

## P5.2 — U-Boot standard boot, environment, FDT and driver model

### Learn

- build/config orientation;
- environment and boot scripts;
- Standard Boot;
- loading kernel/DT/initramfs;
- `bootz`/`booti`/FIT orientation as appropriate to target;
- working FDT vs U-Boot control DT;
- driver-model orientation;
- board defconfig/configuration;
- boot media/image placement;
- interactive debugging commands.

### Exact resource entry

Use **P5.2**: U-Boot documentation sections **Standard Boot**, **Environment Variables**, **Devicetree Control in U-Boot**, **Driver Model**, and the architecture-appropriate boot/image command docs.

### Suggested experiment

Interrupt autoboot, inspect environment, manually load artifacts, inspect/change the working FDT, change exactly one bootarg, boot and state exactly what was passed to Linux.

### Defer

DDR training/SPL/TPL deep porting and unsupported-silicon bring-up until a real target demands them.

---

## P5.3 — Buildroot project customization and package model

### Learn

- defconfig / Kconfig;
- toolchain choices;
- packages;
- overlays;
- post-build/post-image hooks;
- filesystem/image generation;
- `BR2_EXTERNAL`;
- package rebuild/stamp semantics;
- `output/build` vs `output/target` vs `output/images`;
- legal-info/vulnerability/reproducibility orientation.

### Exact resource entry

Use **P5.3**: Buildroot manual headings **Project-specific customization**, **Root filesystem overlays**, **Adding new packages to Buildroot**, **BR2_EXTERNAL**, **Rebuilding packages**, plus Bootlin Buildroot training.

### Suggested project

Create a small `BR2_EXTERNAL` project with one board defconfig, package and overlay; clean-build it; then create a stale package/image situation and diagnose which layer failed to propagate.

---

## P5.4 — Yocto/OpenEmbedded metadata, tasks, signatures and sstate

Do not begin here before Buildroot has made the embedded build-pipeline problem concrete.

### Learn

- Poky/reference-distribution concept;
- OpenEmbedded metadata;
- layers;
- recipes and `.bbappend`;
- machine/distro/image configuration;
- tasks and dependencies;
- task signatures;
- shared state (`sstate`);
- sysroots/work/deploy artifacts;
- package/image relationship;
- kernel recipe/config/patch orientation;
- `devtool` and SDK/eSDK orientation.

### Exact resource entry

Use **P5.4**: Yocto Overview/Concepts sections on layers/recipes/tasks/sstate/signatures plus BitBake execution/dependency/signature material and Bootlin Yocto training.

### Suggested experiment

Build one reference image. Add a package, then a `.bbappend`, then one machine-specific change **separately**. Explain which tasks reran and why.

---

## P5.5 — Kernel/DT patch and configuration management

### Learn

- upstream vs LTS vs vendor kernel;
- config fragments;
- patch series;
- DT source organization;
- backports;
- cost of out-of-tree code;
- BSP upgrades/rebases.

### Exact resource entry

Use **P5.5**: the Yocto **Linux Kernel Development Manual** and **BSP Developer's Guide** when using Yocto, or corresponding Buildroot board/kernel customization guidance, plus the exact upstream/vendor source trees involved.

### Suggested exercise

For one vendor patch, determine subsystem ownership, upstream status, hardware-vs-product-policy nature, and what breaks if the patch is dropped during upgrade.

---

## P5.6 — Image layout, recovery and update architecture

### Learn

- boot partitions;
- rootfs formats;
- read-only/writable areas;
- A/B update concept;
- recovery image;
- artifact versioning;
- signed/verified images orientation;
- rollback and power-loss semantics.

### Exact resource entry

Use **P5.6**: U-Boot image/FIT/verified-boot material where relevant, then the official documentation of an update framework **only after** you have defined the product failure/recovery model.

### Suggested design exercise

Draw a development image layout and a production A/B layout. For every update step, state the outcome of power loss and how rollback is chosen.

---

## P5.7 — Licensing, CVE, SBOM and reproducibility

### Learn

- license obligations at practical depth;
- source offer/notices where applicable;
- package license metadata;
- CVE feed/scanner limitations;
- SBOM concept;
- deterministic/reproducible-build goals;
- exact source/artifact provenance.

### Exact resource entry

Use **P5.7**: Buildroot `legal-info`/license/vulnerability tooling and the matching Yocto license/SPDX/CVE/reproducibility documentation for the version actually used.

### Suggested experiment

For one built image, produce a source/version/license inventory and document one concrete limitation of automated CVE matching.

---

## P5.8 — Reproducible board-integration capstone

Maintain a small integration repository containing **inputs**, not generated build trees:

```text
README / manifest
bootloader config or environment
kernel config fragments / patches
DT changes
Buildroot or Yocto metadata
one application/package
image/update instructions
bring-up/debug notes
```

Use **P5.8** in the topic resource index for the exit criterion.

Practical acceptance:

- clean clone reproduces a bootable image;
- one board-specific change is understood across layers;
- boot artifacts trace back to source/config inputs;
- one stale-build/config fault is diagnosed;
- no unexplained manual edit to generated output is required.

---

# Common traps

- calling a vendor SDK “the BSP” without understanding its layers;
- learning Yocto syntax before understanding the build pipeline;
- editing generated build outputs instead of source metadata;
- carrying patches without checking upstream;
- placing board policy in generic drivers;
- treating DT as a configuration dumping ground;
- relying on undocumented U-Boot environment state;
- mixing development convenience with production update architecture;
- assuming an incremental build proves reproducibility.

# What to defer

Until the role/project needs it:

- secure-boot implementation details;
- TF-A/OP-TEE deep integration;
- advanced UEFI;
- complex OTA frameworks;
- factory provisioning infrastructure;
- large multi-product Yocto distribution architecture;
- custom boot ROM / DDR PHY bring-up.
