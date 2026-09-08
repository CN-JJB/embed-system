# Lab 2.2 — Kconfig Baseline & Fragment Workflow

## Objective
1. Understand why `multi_v7_defconfig` is selected over legacy board defconfigs like `vexpress_defconfig`.
2. Inspect the version-controlled Phase 3 configuration fragment (`phase3_delta.config`).
3. Audit the final effective `.config` file generated after merging the fragment and running `olddefconfig`.

## Canonical Workflow
In an actual Linux source checkout:
```bash
export ARCH=arm
export CROSS_COMPILE=arm-none-linux-gnueabihf-
make multi_v7_defconfig
cat ../../fixtures/configs/phase3_delta.config >> .config
make olddefconfig
```

## Validate Effective Configuration
Run the automated audit script:
```bash
bash apply_config.sh
```
Notice that the validator checks both affirmative options (`CONFIG_ARCH_VIRT=y`, `CONFIG_VMSPLIT_3G=y`) and negative options (`# CONFIG_ARM_LPAE is not set`).
