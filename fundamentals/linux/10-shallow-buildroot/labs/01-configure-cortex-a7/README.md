# Lab 6.1 — Configure Buildroot for the Canonical ARM Target

**Time:** ~40 min. **Prerequisite:** P3-M03/M04 (manual rootfs, BusyBox, QEMU boot).

---

## 1. Why

You have already built this appliance by hand: cross-compiled BusyBox, assembled
an FHS skeleton, written `/init`, and booted it. Every one of those steps was a
decision *you* made. Buildroot's proposition is that one top-level configuration
can drive the toolchain, the packages, the kernel and the root filesystem
images — and that the automation stays transparent enough that you can still
explain each step.

This lab freezes that configuration and, more importantly, freezes it against
**symbols that actually exist** in the pinned release.

---

## 2. Pin the source first

Canonical baseline: **Buildroot 2026.05.2**, tag `2026.05.2`, peeled commit
`72d9d4fa636a371ef9eb99c92a735ce9f6d829d5`.

```bash
curl -LO https://buildroot.org/downloads/buildroot-2026.05.2.tar.xz
tar -xf buildroot-2026.05.2.tar.xz
grep -n '^export BR2_VERSION' buildroot-2026.05.2/Makefile
# 95:export BR2_VERSION := 2026.05.2
```

Do **not** move to a different release. A different Buildroot is a different
contract, and the option names change between releases.

---

## 3. Verify the symbols before you write them down

This is the step people skip, and it is the step that this module was explicitly
written to enforce. Kconfig symbol names are not stable across releases and
nobody remembers them reliably. Look each one up in the source you just
downloaded:

```bash
cd buildroot-2026.05.2
grep -rn '^config BR2_arm$'            arch/Config.in          # 33
grep -rn '^config BR2_cortex_a7$'      arch/Config.in.arm      # 190
grep -rn '^config BR2_ARM_EABIHF$'     arch/Config.in.arm      # 617
grep -rn '^config BR2_ROOTFS_OVERLAY$' system/Config.in        # 655
```

`fixtures/buildroot-symbols.json` is this module's record of that exercise: every
symbol it uses is stored with the file and line where it is declared, so the
configuration can be validated against the real source instead of against
memory.

The validator enforces it:

```bash
python3 scripts/verify_br_config.py fixtures/br2-external/configs/qemu_virt_a7_defconfig \
    --symbol-table fixtures/buildroot-symbols.json --quiet
```

---

## 4. Read the real definitions, not a summary

Three definitions matter for the whole module:

```bash
sed -n '185,200p' arch/Config.in.arm     # BR2_cortex_a7 selects ARMV7A + NEON + VFPV4 + THUMB2
sed -n '585,625p' arch/Config.in.arm     # the EABI / EABIhf choice
sed -n '650,668p' system/Config.in       # BR2_ROOTFS_OVERLAY
```

Two facts fall out of reading them:

* `BR2_cortex_a7` **selects** `BR2_ARM_CPU_HAS_VFPV4`, so the CPU genuinely has a
  hardware floating-point unit — which is why the hard-float ABI is available
  at all.
* `BR2_ARM_EABIHF` **depends on** `BR2_ARM_CPU_HAS_FPU`. Selecting the
  hard-float ABI on a target without an FPU is not merely unwise; the
  configuration system will not let you do it.

---

## 5. The canonical configuration

`fixtures/br2-external/configs/qemu_virt_a7_defconfig` is the frozen answer.
Read it. The parts that matter:

```text
BR2_arm=y
BR2_cortex_a7=y
BR2_ARM_EABIHF=y
```

`BR2_ARM_EABIHF=y` is not cosmetic: the Phase 3 userspace ABI is hard-float.
Every binary in the rootfs is compiled for it, and the dynamic loader is
`/lib/ld-linux-armhf.so.3`. Select soft-float `BR2_ARM_EABI` and the rootfs
cannot run the userspace you built in P3-M03 — which is exactly what the
Challenge in this module seeds.

> **Note.** `BR2_ROOTFS_OVERLAY` is set through
> `$(BR2_EXTERNAL_QEMU_VIRT_A7_PATH)`, the path variable Buildroot defines for
> an external tree. That is the idiomatic form, and it is also why the module's
> validator permits exactly that one expansion and rejects every other
> `$(...)`: a configuration fragment is data, not a script.

---

## 6. Configure, do not hand-edit

```bash
make -C buildroot-2026.05.2 O=$PWD/build/br-output \
     BR2_EXTERNAL=$PWD/fixtures/br2-external qemu_virt_a7_defconfig
```

Then compare what Buildroot produced with what you froze:

```bash
diff <(grep -v '^#' build/br-output/.config | grep .) \
     <(grep -v '^#' fixtures/br2-external/configs/qemu_virt_a7_defconfig | grep .)
```

Extra lines are normal — a defconfig is a *minimal* declaration and Buildroot
expands it with defaults. What must not differ is the value of any symbol you
declared.

---

## 7. Checkpoint

1. You can point at the file and line where each symbol in the canonical
   defconfig is declared.
2. You can explain why `BR2_ARM_EABIHF` is available for `cortex-a7` (follow the
   `select` chain) and what breaks if you choose `BR2_ARM_EABI` instead.
3. `scripts/verify_br_config.py ... --symbol-table ...` passes.

**Non-proof.** A valid configuration proves that the *selection* is coherent. It
proves nothing about what a build produces, and nothing at all about whether an
image boots.
